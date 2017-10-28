import unfoldtext;
import message;
import std.conv;
import std.string;
import std.stdio;
import std.algorithm;

enum messageComponents
  {
    Subject,
    Date,
    To,
    From,
    Return_Path,
    Received,
    Message_ID,
    Unknown
  }

struct messagePart
{
  string label;
  string data;
  bool repeatable; // True if this can appear more than once in a message.
  bool found;
  UnfoldText unfolder;
}

class ProcessMessageData
{
private:
  //  messagePart *target;
  messagePart[messageComponents] messageParts;
  messageComponents part = messageComponents.Unknown;

  messageComponents getComponentType(in string text) pure @trusted
  {
    auto range = messageParts.byKey();
    foreach(ref x; range) {
      // If we find it, the next line is to process text and insert it somewhere.
      // But we can't have found it before, unless it is a repeatable type.
      if (text.startsWith(messageParts[x].label) && (messageParts[x].label.length > 1)) {
	return x;
      }
    }
    // If we didn't find it, don't change a thing.
    return messageComponents.Unknown;
    // We are only intersted if we come accross a new type.
  }

  void reset() @trusted
  {
    auto range = messageParts.byValue();
    foreach(ref x; range) {
      x.data = "";
    }
  }
public:

  void processMessagePart(in string text) @safe
  {
    immutable auto newType = getComponentType(text); // The type of component we are going to process.
    auto currentMessagePart = messageParts[part]; // Point to the messagePart we are processing

    if (newType != messageComponents.Unknown) {
      // If a new type, definately process if not found.
      // Old item is now found, if the previous line was a compenent type we wanted.
      if (part != messageComponents.Unknown) {
	if (currentMessagePart.repeatable == false) {
	  currentMessagePart.found = true;
	}
      }
      currentMessagePart = messageParts[newType];  // Point to the new type

      if (currentMessagePart.found == true) {  // If its been found and we don't want another, ignore. {
	part = messageComponents.Unknown;
	return;
      } else {
	// We will process it
	part = newType;
	currentMessagePart.unfolder.addLine(text[(currentMessagePart.label.length)..$]);
      }
    } else if ((part != messageComponents.Unknown) && (!text.startsWith(" ") && !text.startsWith("\t"))) {
      // newType is unknown.
 
      // We are processing a known type, but not a continue line.  This is the end of the part.
      part = messageComponents.Unknown;
      // If not a type we expect to repeat, mark it as found
      if (currentMessagePart.repeatable == false) {
	currentMessagePart.found = true;
      }
    }

    if ((part != messageComponents.Unknown) && (text.startsWith(" ") || text.startsWith("\t"))) {
      // A continue line, and we are processing a known type.
      currentMessagePart.unfolder.addLine(strip(text));
    }
  }

  this() @safe
  {
    messageParts[messageComponents.Subject] = messagePart("Subject:", "",false, false);
    messageParts[messageComponents.Date] = messagePart("Date:", "",false, false);
    messageParts[messageComponents.To] = messagePart("To:", "", false, false);
    messageParts[messageComponents.From] = messagePart("From:", "", false, false);
    messageParts[messageComponents.Return_Path] = messagePart("Return-Path:", "", false, false);
    messageParts[messageComponents.Received] = messagePart("Received:", "", true, false);
    messageParts[messageComponents.Message_ID] = messagePart("Message-ID:", "", false, false);
    messageParts[messageComponents.Unknown] = messagePart("", "", true, true);

    foreach(ref x; messageParts) {
      x.unfolder = new UnfoldText();
    }

  }

  Message messageFactory(in string eml) @safe
  {
    scope(exit) reset;

    auto split = eml.lineSplitter;
    foreach(x; split) {
	processMessagePart(x);
      }
    unfoldMessage();
    Message m = new Message(
			    messageParts[messageComponents.Subject].data,
			    messageParts[messageComponents.Date].data,
			    messageParts[messageComponents.To].data,
			    messageParts[messageComponents.From].data,
			    messageParts[messageComponents.Return_Path].data,
			    messageParts[messageComponents.Received].data,
			    messageParts[messageComponents.Message_ID].data,
			    );
    return m;
  }

  void unfoldMessage() @safe
  {
    foreach(ref x; messageParts) {	
      x.data = x.unfolder.unfolded;
    }
  }
	      
  void print() @safe
  {
    foreach(ref x; messageParts) {
      writeln(x.label, x.data);
    }
  }
}




