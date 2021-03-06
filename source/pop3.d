// Written in the D Programming language.
/*
 * Sanspam: Mailbox utility to delete/bounce spam on server interactively.
 * Copyright (C) 2018  Dennis Katsonis dennisk@netspace.net.au
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import std.typecons;
import std.string;
import std.exception;
import std.conv;
import std.algorithm;
import buffer;
import socket;
import config;
import message;
import mailprotocol;
import sanspamexception;
import processline;
import exceptionhandler;

string OK = "+OK";
string ERROR = "-ERR";

class Pop3 : MailProtocol
{
private:
  final MessageStatus evaluateMessage(const ref string message, Flag!"multiline" multiline) const @safe
  {
    string end = (multiline == Yes.multiline) ? "\r\n.\r\n" : "\r\n";

    if ((multiline == Yes.multiline) && (!message.endsWith(end))) {
      return MessageStatus.INCOMPLETE;
    }

    //  Whether there response is OK or ERROR.
    if (message.startsWith(OK)) {
      return MessageStatus.OK;
    } else if(message.startsWith(ERROR)) {
      return MessageStatus.BAD;
    } else {
      return MessageStatus.INCOMPLETE;
    }
  }
  
public:
  this() {}

  final this(in string server, in ushort port) @safe
  {
    m_socket = new MailSocket(server, port);
    if (port == 995) {
      m_socket.startSSL;
    }
    auto b = m_socket.receive.bufferToString();
    if(evaluateMessage(b, No.multiline) == MessageStatus.BAD) {
      throw new SanspamException("Cannot create socket","Could not create connection with server.");
    }
  }

  final ~this()
  {
    if(m_socket !is null) {
      destroy(m_socket);
    }
  }


  override final string getUID(in int messageNumber) @safe
  {
    string UIDquery = "UIDL "~messageNumber.to!string;
    auto UIDresponse = query(UIDquery);
    if (UIDresponse.status == MessageStatus.BAD) {
      throw new SanspamException("POP3 transfer failure", "Failed to execute query "~UIDquery);
    } else {
      auto results = UIDresponse.contents.split;
      return results[1];
    }

  }

  final void getCapabilities() @safe
  {
    auto response = query(getQueryFormat(Command.Capability));
    if (response.status == MessageStatus.BAD)
      return;
    auto results = split(response.contents.toUpper);
    if (find(results, "UIDL").length) m_supportUID = true;
    if (find(results, "TOP").length) m_supportTOP = true;
  }

  
  override final bool login(in configstring username, in configstring password) @safe
  {
    string loginQuery = "USER "~username;
    auto x = query(loginQuery);
    if (x.status == MessageStatus.BAD || x.status == MessageStatus.INCOMPLETE) {
      m_connected = false;
      throw new SanspamException("Failed to connect", x.contents~" : Incorrect username or password");
    }

    loginQuery = "PASS "~password;
    x = query(loginQuery);
    if (x.status == MessageStatus.BAD || x.status == MessageStatus.INCOMPLETE) {
      m_connected = false;
      throw new SanspamException("Failed to connect", x.contents~" : Incorrect username or password");
    }

    m_connected = true;
    getNumberOfMessages;
    getCapabilities;
    return false;
  }


  override final queryResponse query(in string command, Flag!"multiline" multiline = No.multiline) @safe 
  {
    queryResponse response;
    m_socket.send(command~endline);

    Buffer buffer = m_socket.receive;
    auto message = buffer.text;
    //    buffer.reset;
    // Evaluate response.
    //    immutable MessageStatus responseStatus = evaluateMessage(message);
    MessageStatus isOK = evaluateMessage(message, multiline);
    
    while (isOK == MessageStatus.INCOMPLETE) {
      buffer.reset;
      buffer = m_socket.receive;
      message ~= buffer.text;
      isOK = evaluateMessage(message, multiline);
    }

    if (isOK == MessageStatus.OK) {
      response.contents = message.chompPrefix(OK);
    } else if(isOK == MessageStatus.BAD) {
      response.contents = message.chompPrefix(ERROR);
    }
    response.status = isOK;
    return response;
  }

    override final string getQueryFormat(Command command) @safe pure
  {
    string commandText;
    
    switch(command)
      {
      case Command.Delete:
	commandText = "DELE %d";
	break;
      case Command.Close:
	commandText = "QUIT";
	break;
      case Command.Logout:
	commandText = "LOGOUT";
	break;
      case Command.Capability:
	commandText = "CAPA";
	break;
      default:
	break;
	
      }
    return commandText;
  }


  final int getNumberOfMessages() @trusted
  // Returns the number of e-mails, or -1 in case of error.
  {
    immutable auto response = query("STAT");
    if (response.status == MessageStatus.BAD)
      return 0;

    immutable auto result = response.contents.split;
    auto numberOfMessages = result[0].to!int;
    m_mailboxSize = numberOfMessages;
    return m_mailboxSize;

  }

  override final bool loadMessages() @safe
  {
    if (m_mailboxSize == 0) {
      return true;
    }

    m_messages.clear; // We load all again.  Clear any existing messages.

    ProcessMessageData pmd = new ProcessMessageData();

    for(int x = 1; x <= m_mailboxSize; x++)
      {
	Message m;
	string messageQuery = "TOP "~x.to!string~" 0";
	immutable auto response = query(messageQuery, Yes.multiline);
	if (response.status == MessageStatus.BAD) {
	  throw new SanspamException("Failed to download e-mail message", "Message number "~x.to!string~" could not be downloaded.");
	}
	m = pmd.messageFactory(response.contents);
	
	if(m_supportUID) {
	  m.uidl = getUID(x);
	}
	m.number = x;
	m_messages.add(m);
      }
    return true;
  }


  override final void selectFolder(ref Folder folder) @safe
  {
    return;
  }
  

  override final FolderList folderList() @safe
  {
    return m_folderList;
  }
  
}

unittest
{
  MailProtocol d = new Pop3;
  assert(insertValue(d.getQueryFormat(Command.Delete),4) == "DELE 4");
  assert(d.getQueryFormat(Command.Logout) == "LOGOUT");
  assert(d.getQueryFormat(Command.Close) == "QUIT");
}
