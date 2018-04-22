/*
 * Spaminex: Mailbox utility to delete/bounce spam on server interactively.
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

import mailprotocol;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.array;
import std.conv;
import std.stdio;
import std.string;
import std.format;
import config;
import exceptionhandler;
import spaminexexception;
import mailbox;
import ui;


int main()
{
  
  scope(exit) {
    endwin;
  }
  debug {
    writeln("Debug mode");
    Mailbox mailbox;
    FolderList d;
    
    try {
      mailbox = new Mailbox("hotmail");
      mailbox.login;
    } catch (SpaminexException e) {
      auto except = new ExceptionHandler(e);
      except.display;
    }
  }
  
  /*    
    try {
      mailbox.loadMessages;
    } catch (SpaminexException e) {
      auto except = new ExceptionHandler(e);
      except.display;
    }


    foreach(ref m; mailbox)
      {
	writeln(m.subject);
	writeln("UIDL", m.uidl);
      }
  */
  
  initCurses;
  mainWindow;
  createStatusWindow;
  string account;
  
  while((account = accountSelectMenu) != "")
  {
    editAccount(account);
    // No text, means the user wanted to quit.

  }
  
  endwin;
  //  writeln(account);
  
  /*
    
    foreach(c; xx) {
    Mailbox mailbox;
    try {
    writeln();
    mailbox = new Mailbox(c.to!string);
    mailbox.login;
    } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
    }
    try {
    mailbox.loadMessages;
    }
    catch (SpaminexException e) {
    writeln("Exception");
    ExceptionHandler x = new ExceptionHandler(e);
    x.display;
    }
    foreach(m; mailbox) {
    auto writer = appender!string();
    }
    mailbox.close;    
    }
  */
  /*
    Mailbox mailbox = new Mailbox("iinet");
    mailbox.login;
    FolderList f = mailbox.folderList;
    writeln(f);
    mailbox.selectFolder(f[0]);
    mailbox.loadMessages;
    foreach(a; mailbox)
    {
    write(a.subject," ", a.from);
    writeln;
      
    }
  */
  return 0;

}

