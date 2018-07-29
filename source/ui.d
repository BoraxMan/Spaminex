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


// This has code specific to the Spaminex UI.

import core.stdc.errno;
import core.sys.posix.sys.ioctl;
import core.stdc.signal;
import std.stdio;
import deimos.ncurses;
import deimos.ncurses.menu;
import std.string;
import std.conv;
import std.string;
import message;
import config;
import exceptionhandler;
import spaminexexception;
import mailbox;
import mailprotocol;
import uidefs;


void mainMenuHelp()
{
    writeStatusMessage("Up/Down to navigate. Enter to select account.  (L)icense, (A)bout, (Q)uit.");
}

void termResize()
{

  winsize size;
  int x;
  int y;
  if (termResized == true) {
    if (ioctl(stdout.fileno(), TIOCGWINSZ, &size) == 0) {
      y = size.ws_row;
      x = size.ws_col;
    }
    if (accountEditWindow !is null) {
      wresize(accountEditWindow, y-3,x-2);
      wrefresh(accountEditWindow);
    }
    if (headerWindow !is null) {
      wresize(headerWindow,y-1, x);
      wrefresh(headerWindow);
    }
    refresh;
    termResized = false;
  }
}
extern (C) void function(int) nothrow @nogc @system d;

extern (C) {
  /* We have very limited ability to respond to a signal that the terminal has been resized.
Only set the bool to true.  Handle resize in the event loop to manage input.
  */
  
  void doResize(int x = 0) nothrow @nogc @system
  {
    termResized = true;
  }
}


void editAccount(in string account, in string folder = "")
{
  doResize(3);
  d = &doResize;
  signal(28, d);
  MENU* messageMenu = null;
  ITEM*[] messageItems;
  ITEM* currentItem;
  Mailbox mailbox;

  scope(exit)
    {

      foreach(ref x; messageItems ) {
	free_item(x);
      }
      
      if (messageMenu != null) {
	free_menu(messageMenu);
      }

      if (accountEditWindow != null) {
	
	wclear(accountEditWindow);
	wrefresh(accountEditWindow);
	delwin(accountEditWindow);
	accountEditWindow = null;
      }
      destroy(mailbox);
      clearStatusMessage;      
    }
  
  accountEditWindow = newwin(LINES-3,COLS-2,1,1);
  menu_opts_off(messageMenu, O_ONEVALUE);
  int x;
  
  try {
    mailbox = new Mailbox(account);
    mailbox.login;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
    return;
  }

  if (mailbox.protocol == Protocol.IMAP)
    {
      FolderList folderList = mailbox.folderList;
      foreach(a;folderList)
	{
	  if (a.name == "INBOX") {
	    mailbox.selectFolder(a);
	  }
	}
    }
      
  try {
    mailbox.loadMessages;
  } catch (SpaminexException e) {
    auto except = new ExceptionHandler(e);
    except.display;
  }

  foreach(ref m; mailbox)
    {
      currentItem = new_item(m.from[0..((m.from.length < COLS/3) ? m.from.length : COLS/3)].toStringz, m.subject.toStringz);
      if (currentItem == null) {
	string error;
	if (errno == E_BAD_ARGUMENT) {
	  error = "Incorrect or out of range argument";
	} else if (errno == E_SYSTEM_ERROR) {
	  error = "System error (out of memory?)";
	} else {
	  error = "Unknown error";
	}
	throw new SpaminexException("Failed creating menu entry for "~m.subject.replace(":","I"),error);
      }
      set_item_userptr(currentItem, &m);
      
      messageItems~= currentItem;
    }
  
  messageItems~=null;
  
  messageMenu = new_menu(messageItems.ptr);
  if (messageMenu == null) {
    throw new SpaminexException("Internal Error","Could not create menu of messages for account "~account);
  }

  set_menu_win(messageMenu, accountEditWindow);
  set_menu_sub(messageMenu, derwin(accountEditWindow,LINES-4,COLS-2,0,0));
  set_menu_mark(messageMenu, "*");
  set_menu_format(messageMenu,LINES-4,1);
  
  set_menu_fore(messageMenu, COLOR_PAIR(ColourPairs.AccountMenuFore));
  set_menu_back(messageMenu, COLOR_PAIR(ColourPairs.AccountMenuBack));

  keypad(accountEditWindow, true);

  post_menu(messageMenu);
  int accountx, accounty;
  string footer;
  getmaxyx(accountEditWindow,accounty, accountx);
  wmove(accountEditWindow,accounty,1);
  if (mailbox.size == 0) {
    footer~="No e-mails.";
  } else if (mailbox.size == 1) {
    footer~="1 e-mail.";
  } else {
    footer~=mailbox.size.to!string~" e-mails.";
  }
  footer~="  Editing account : "~account~".";
  wprintw(accountEditWindow,footer.toStringz);
  wrefresh(accountEditWindow);
  writeStatusMessage("(D)elete, (B)ounce and delete, (Q)uit, (C)ancel and quit");
  
  int c;
  while ((c = wgetch(accountEditWindow)) != 'q')
    {
      switch (c)
	{
	case 'c':
	  goto case;
	case 'C':
	  return;
	case KEY_DOWN:
	  menu_driver(messageMenu, REQ_DOWN_ITEM);
	  break;
	case KEY_UP:
	  menu_driver(messageMenu, REQ_UP_ITEM);
	  break;
	case KEY_NPAGE:
	  menu_driver(messageMenu, REQ_SCR_DPAGE);
	  break;
	case KEY_PPAGE:
	  menu_driver(messageMenu, REQ_SCR_UPAGE);
	  break;
	case 'b':
	  goto case;
	case 'B':
	  (cast(Message*)item_userptr(current_item(messageMenu))).bounce = true;
	  goto case;
	case 'd':
	  goto case;
	case 'D':
	  (cast(Message*)item_userptr(current_item(messageMenu))).deleted = true;
	  menu_driver(messageMenu, REQ_TOGGLE_ITEM);
	  break;
	case KEY_RESIZE:
	  return;

	default:
	  break;
	}
            termResize;
      wrefresh(accountSelectionWindow);
    }

  for (int count = 0; count < item_count(messageMenu); count++) {
    if(item_value(messageItems[count]) == true) { // Has been tagged in the menu.
      if((mailbox.remove(count+1, (cast(Message*)item_userptr(messageItems[count])).uidl)) == false) {
	writeStatusMessage("FAILED to delete message for "~(cast(Message*)item_userptr(messageItems[count])).uidl);
      } else {
	writeStatusMessage("Deleted message "~(cast(Message*)item_userptr(messageItems[count])).uidl);
      }
      
      if(((cast(Message*)item_userptr(messageItems[count])).bounce) == true) {
	writeStatusMessage("Bouncing to "~(cast(Message*)item_userptr(messageItems[count])).from);
	mailbox.bounceMessage(count+1);
	clearStatusMessage;

      }
    }
  }

  mailbox.close;
  
  wrefresh(accountEditWindow);
}

void mainWindow()
{
  headerWindow = create_newwin(LINES-1,COLS,0,0,ColourPairs.MainBorder, ColourPairs.MainTitleText,"--== SPAMINEX ==--");
}

void showAbout()
{
  WINDOW *aboutWindow = null;
  immutable int aboutWindowWidth = 70;
  string[] aboutText =  [
    "SPAMINEX, by Dennis Katsonis, 2018",
    "",
    "Spaminex is an interactive tool to allow you to easily scan your",
    "e-mail Inbox and delete any messages you don't want.  In addition",
    "to this, you can bounce back an error message to the sender, which",
    "may dissuade spammers from reusing your e-mail address.",
    "Spaminex is inspired by Save My Modem by Enrico Tasso",
    "and SpamX by Emmanual Vasilakis, which are two simple, easy",
    "to set up tools that I used to use, but aren't maintained anymore.",
    "Refer to the README file for help on how to configure Spaminex.",
    "",
    "This program is intended for simple, basic e-mail pruning."];
  aboutWindow = create_newwin(aboutText.length.to!int+2,aboutWindowWidth,3,1,ColourPairs.MainBorder, ColourPairs.MainTitleText,"About Spaminex");
  wattron(aboutWindow, COLOR_PAIR(ColourPairs.StandardText));

  int line = 1;
  foreach(ref x; aboutText) {    
    mvwprintw(aboutWindow, line++, 1, x.toStringz);
  }

  wrefresh(aboutWindow);
  writeStatusMessage("Press any key to return.");
  touchwin(aboutWindow);
  wgetch(aboutWindow);
  wclear(aboutWindow);
  wrefresh(aboutWindow);
  delwin(aboutWindow);
}

void showLicence()
{
  WINDOW *licenseWindow = null;
  immutable int licenseWindowWidth = 72;
  string[] licenseText =  [
    "Copyright Dennis Katsonis, 2018",
    "",
    "This program is free software: you can redistribute it and/or modify",
    "it under the terms of the GNU General Public License as published by",
    "the Free Software Foundation, either version 3 of the License, or",
    "(at your option) any later version.",
    "",
    "This program is distributed in the hope that it will be useful,",
    "but WITHOUT ANY WARRANTY; without even the implied warranty of",
    "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the",
    "GNU General Public License for more details.",
    "You should have received a copy of the GNU General Public License",
    "along with this program.  If not, see <http://www.gnu.org/licenses/>."];
  
  licenseWindow = create_newwin(licenseText.length.to!int+2,licenseWindowWidth,3,1,ColourPairs.MainBorder, ColourPairs.MainTitleText,"LICENSE");
  wattron(licenseWindow, COLOR_PAIR(ColourPairs.StandardText));

  int line = 1;
  foreach(ref x; licenseText) {    
    mvwprintw(licenseWindow, line++, 1, x.toStringz);
  }

  wrefresh(licenseWindow);
  writeStatusMessage("Press any key to return.");
  touchwin(licenseWindow);
  wgetch(licenseWindow);
  wclear(licenseWindow);
  wrefresh(licenseWindow);
  delwin(licenseWindow);
}


void initCurses()
{
  initscr;
  start_color;
  init_pair(ColourPairs.MainTitleText, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(ColourPairs.MainBorder, COLOR_CYAN, COLOR_BLACK);
  init_pair(ColourPairs.StatusBar, COLOR_WHITE, COLOR_RED);
  init_pair(ColourPairs.MenuFore, COLOR_YELLOW, COLOR_BLUE);
  init_pair(ColourPairs.MenuBack, COLOR_GREEN, COLOR_BLACK);
  init_pair(ColourPairs.AccountMenuFore, COLOR_WHITE, COLOR_RED);
  init_pair(ColourPairs.AccountMenuBack, COLOR_WHITE, COLOR_BLACK);
  init_pair(ColourPairs.StandardText, COLOR_WHITE, COLOR_BLACK);
  
  cbreak;
  noecho;
  keypad(stdscr,true);
  refresh;
}


string accountSelectMenu()
{
  
  
  MENU* mailboxMenu = null;
  ITEM*[] mailboxes;
  ITEM* currentItem = null;
  int c;
  string account;

  scope(exit) {
    clearStatusMessage;
    foreach(ref x; mailboxes) {
      free_item(x);
    }
      
    if (mailboxMenu != null) {
      free_menu(mailboxMenu);
      mailboxMenu = null;
    }

    if (accountSelectionWindow != null) {
      wclear(accountSelectionWindow);
      wrefresh(accountSelectionWindow);
      delwin(accountSelectionWindow);
      accountSelectionWindow = null;
    }
      
  }

  accountSelectionWindow = create_newwin(10, COLS-10,(LINES/2-5),5,ColourPairs.MainTitleText, ColourPairs.MainBorder,"Select Account");
  mainMenuHelp;
  auto xx = configurations.byKey();
  foreach(conf; xx) {
    //    mailboxes~=new_item(conf.to!string.toStringz,conf.to!string.toStringz);
    currentItem = new_item(conf.to!string.toStringz,"".toStringz);
    if (currentItem == null) {
      throw new SpaminexException("Could not create menu entry","Failed creating menu entry for "~conf.to!string);

    }
    mailboxes~=currentItem;
  }

  mailboxes~=null;
  mailboxMenu = new_menu(mailboxes.ptr);
  if (mailboxMenu == null) {
    throw new SpaminexException("Internal Error","Could not allocate menu.");
  }
  
  set_menu_win(mailboxMenu, accountSelectionWindow);
  set_menu_sub(mailboxMenu,derwin(accountSelectionWindow,6,38,3,1));
  set_menu_mark(mailboxMenu," * ");
  set_menu_fore(mailboxMenu, COLOR_PAIR(ColourPairs.MenuFore));
  set_menu_back(mailboxMenu, COLOR_PAIR(ColourPairs.MenuBack));

  keypad(accountSelectionWindow,true);
  post_menu(mailboxMenu);
  wrefresh(accountSelectionWindow);

  while ((c = wgetch(accountSelectionWindow)) != 'q')
    {
      switch (c)
        {
	case 'a':
	  goto case;
	case 'A':
	  showAbout;
	  touchwin(accountSelectionWindow);
	  redrawwin(accountSelectionWindow);
	  mainMenuHelp;
	  break;
	case 'l':
	  goto case;
	case 'L':
	  showLicence;
	  touchwin(accountSelectionWindow);
	  redrawwin(accountSelectionWindow);
	  mainMenuHelp;
	  break;
        case KEY_DOWN:
	  menu_driver(mailboxMenu, REQ_DOWN_ITEM);
	  break;
        case KEY_UP:
	  menu_driver(mailboxMenu, REQ_UP_ITEM);
	  break;
        case KEY_NPAGE:
	  menu_driver(mailboxMenu, REQ_SCR_DPAGE);
	  break;
        case KEY_PPAGE:
	  menu_driver(mailboxMenu, REQ_SCR_UPAGE);
	  break;
	case ' ':
	case '\n':
	  menu_driver(mailboxMenu, REQ_TOGGLE_ITEM);
	  account = item_name(current_item(mailboxMenu)).to!string;
	  return account;
        default:
	  break;
        }
      wrefresh(accountSelectionWindow);
      termResize;
    }
  return account;
}
