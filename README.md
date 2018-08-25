SPAMINEX, by Dennis Katsonis, 2018

* Introduction

Spaminex is an interactive tool to allow you to easily scan your e-mail Inbox and delete any messages you don't want.  In addition to this, you can bounce back an error message to the sender, which may dissuade spammers from reusing your e-mail address. Spaminex is inspired by Save My Modem by Enrico Tasso and SpamX by Emmanual Vasilakis, which are two simple, easy to set up tools that I used to use, but aren't maintained any more and require too much work to justify update.

This program is intended for simple, basic e-mail pruning.

Spaminex supports POP and IMAP accounts, and also supports SSL for secure connections.

This is more suited to those who use e-mail clients and prefer to download messages to their computer, but also prefer not to allow spam, or potentially harmful messages to be downloaded at all.  Instead of running a risk having it downloaded by the e-mail client, Spaminex allows you to delete it on the server, without being exposed to any attachments or e-mail content.

* How to use

Spaminex reads its options from an INI style configuration file.  The configuration file lives in the .config/spaminex/ directory/folder in your home directory and is titled "accounts.conf".  Create a directory called "spaminex" in your ".config" folder and using your preferred text editor, create a file called "accounts.conf".  

Check the Configuration Options section below for configuration options.

When spaminex is started, it displays a list of configured e-mail accounts.  Selecting the account will then display a list of e-mails.  Use the arrows to navigate and and down the list and press "I" if you want further details on the e-mail.  While in the e-mail list, you can press D to mark the message for deletion or B to mark it for bounce and deletions.  Bounced messages will be sent back to the sender with a fake error, designed to possibly fool the sender into considering the e-mail address invalid and therefore not a suitable target for more spam.  An SMTP server must be configured to bounce messages.  It is recommended that the bounce option be used frugally.

Pressing Q will Quit, and delete all selected messages and bounce those marked for deletion.  Pressing C will cancel all operations and no e-mails will be deleted.

* Configuration Options

Configuration is in configuration group, with each group pertaining to a specific e-mail account you have.  The account name is specified on its own line between square brackets "[ & ]".  After this, list your options in the format...

option = value.

Valid options are

username
	The username used to log into the mail server.
	
password
	The password used to log into the mail server.  Note that this is stored in plain text, so the configuration file should be kept secure.  If no password is supplied, Spaminex will prompt for one.  (optional).

pop
	The incoming pop server if using a POP account.
	
imap
	The incoming imap server of using an IMAP account.
	
smtp
	The outgoing SMTP server (optional).

port
	The port number of the incoming server.  Typically 110 for POP and 143 for IMAP, 993 for POP using SSL.
	
type
	imap or pop
	
smtp_port
	The port number of the SMTP server (optional).
	
An example is below...

[hotmail]
smtp_port = 25
port = 993
type = imap
password = ThePassword
pop = pop.outlook.com
imap = imap-mail.outlook.com
username = JohnDoe@hotmail.com

* Development

This is partly written for personal use, and partly as a small project to begin learning the D Programming Language.  It is my first proper D program, though still somewhat written in an idiomatic C++ style instead of an idiomatic D style.
