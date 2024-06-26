/**
 * Most of the functions in this script are related to strings and string colors
 * and should be reusable with minimum effort (g_bIsCSGOColors can be replaced
 * with GetEngineVersion()==Engine_CSGO)
 *
 * Function overview:
 * ParseChatColor - Read color native at input[0] if < 32 or resolve input as color name
 * GetNativeColor - Read a color native at the given position, if present
 * RemoveTextColors - Remove color natives and optionally color tags from input
 * StringStartsWithColor - Skip-space (32) looking for control characters
 * GetStringColor - Search color before or after text
 * GetCodePoint - Reads a UTF8 Multibyte character codepoint from the first byte
 * GetPreviousCharMB - Utility to reverse seek through MB strings
 * IsCharMBSpace - Checks for Multibyte space characters at the given position
 * TrimStringMB - Trims Multibyte space characters of a buffer
 * copyNchars - Does offset math to strcopy for you
 * CollapseColors - Remove redundant colors from a string
 */
#if defined _mcp_strings
#endinput
#endif
#define _mcp_strings
#if !defined _MetaChatProcessor_
#error Please compile the main file
#endif

#include <multicolors>

/**
 * roughly check if the color is a valid color code, or a rgb/rgba color specifier, or and existing color name
 * and return the native color string for that color.
 * for CSGO: check if strlen==1 && 0<char[0]<32
 * for old source: check if 0<char[0]<=6 && strlen == 1 || char[0]==7/'#' && strlen == 7 || char[0]==9/'#' && strlen==9
 * for all: check if string is valid color name
 * note: output size should be at least 2
 * @param color - the color specifier,
 * @param output - the native color \x01..\x10 i think for csgo, \x01..\x08 for others
 * @param maxsize - size of output buffer
 * @return true if the color seemd valid and output was set.
 */
bool ParseChatColor(const char[] color, char[] output, int maxsize, int author) {
	if (!color[0]) return false;
	//control character == native color
	if( (GetEngineVersion() == Engine_CSGO && 0 < color[0] <= 0x10) ||
		(color[0] <= 0x06) ){ //all default colors supported by non csgo
		output[0] = color[0];
		output[1] = 0;
		return true;
	} else if (color[0] == 7 || color[0] == 8 || color[0] == '#' ) {
		//color buffer is \x07rrggbb\x00 OR \x08rrggbbaa\x00
		int bytes = 8;
		int inlen = strlen(color);
		if (color[0]=='#') {
			if (inlen == 9) bytes = 10;
			else if (inlen != 7) ThrowError("Input has no complete color hex tag!");
		} else if (color[0]==8) {
			if (inlen != 9) ThrowError("Input has no complete x8 color tag!");
			bytes = 10;
		} else if (inlen != 7) ThrowError("Input has no complete x7 color tag!");
		if (bytes > maxsize) ThrowError("Output can't hold color format");
		strcopy(output, bytes, color);
		output[0] = (bytes==10)?8:7;
		return true;
	} else if( CColorExists(color) ){ //multicolor has names for CSGO colors, so we should be good
		char tmp[32];
		FormatEx(tmp, sizeof(tmp), "{%s}", color);
		CFormatColor(tmp, sizeof(tmp), author);
		strcopy(output, maxsize, tmp);
		return true;
	}
	output[0] = 0;
	return false;
}


/**
 * Get the native color code at the start of the given buffer
 * @param buffer - search text, user charptr[at] for offsets
 * @param out - color code output
 * @param maxlen - output size
 * @return length of color code or 0 if not a color
 */
int GetNativeColor(const char[] buffer, char[] out="", int maxlen=0) {
	if (buffer[0] == 0) { //not a color
		return 0;
	} else if (buffer[0]<=0x10 && g_bIsCSGOColors) { //csgo colors
		if (maxlen) strcopy(out, 2>maxlen?maxlen:2, buffer);
		return 1;
	} else if (buffer[0] == 7) { //'09 rgb
		if (maxlen) strcopy(out, 8>maxlen?maxlen:8, buffer);
		return 7;
	} else if (buffer[0] == 8) { //'09 rgba
		if (maxlen) strcopy(out, 10>maxlen?maxlen:10, buffer);
		return 9;
	} else if (buffer[0] <= 6) { //'09 colors
		if (maxlen) strcopy(out, 2>maxlen?maxlen:2, buffer);
		return 1;
	} else { //other character
		return 0;
	}
}

/**
 * Removes all color tags and color codes from a message as well as other control
 * characters that probably don't belong there.
 * Fun fact: TF2 removes colors from msg_name parameters by replacing code bytes
 * (7 bytes for \x07, 9 bytes for \x09) with \x01, but I don't know on what end
 *
 * @param message - the message to process
 * @param maxsize - the max buffer size
 * @param removeTags - remove color tags
 * @return true if changed
 */
bool RemoveTextColors(char[] message, int maxsize, bool removeTags=true) {
	int strlenStart = strlen(message);
	if (removeTags) CRemoveTags(message, maxsize);
	int read,write;
	if (GetEngineVersion()==Engine_CSGO) {
		for (;message[read] && read < maxsize;read+=1) {
			if (0 < message[read] <= 0x10) continue; //skip all colors
			if (read!=write)
				message[write] = message[read];
			write+=1;
		}
	} else {
		for (;read < maxsize && message[read];read+=1) {
			if (message[read] == 7) { read+=6; continue; } //skip following RRGGBB as well
			else if (message[read] == 8) { read+=8; continue; } //skip following RRGGBBAA as well
			else if (0 < message[read] <= 6) continue; //skip all simple colors
			if (read!=write)
				message[write] = message[read];
			write+=1;
		}
	}
	if (read!=write) {//changed
		//move 0 terminator as well; max index is at size-1
		if (write < maxsize-1) message[write]=0;
		else message[maxsize-1] = 0; //safety
	}
	return read == strlenStart;
}


/** @return index to color char or -1 */
int StringStartsWithColor(const char[] buffer) {
	int at=0,w;
	for (;buffer[at] != 0;) {
		if (GetNativeColor(buffer[at])) return at;
		else if (buffer[at]<=32) at += 1; //these wont print, so we can skip em
		else if (IsCharMBSpace(buffer[at],w)) at += w;
		else return -1;
	}
	return -1;
}
/**
 * normal mode gets the color only if it is in front of any printable characters (>32)
 * post mode is intended to get the color a concatinated string would inherit
 */
bool GetStringColor(const char[] buffer, char[] color, int bufsize, bool post=false) {
	if (post) {
		for (int i=strlen(buffer)-1; i>=0; i-=1) {
			if (GetNativeColor(buffer[i], color, bufsize)) {
				return true;
			}
		}
		return false;
	} else {
		int at;
		return ((at = StringStartsWithColor(buffer))>=0 && GetNativeColor(buffer[at], color, bufsize));
	}
}

/**
 * @param bytes, width of the character returned, 0 for broken MB chars
 * @return codepoint or 0 if a MB character is broken
 */
int GetCodePoint(const char[] buffer, int& bytes=0) {
	int cp;
	if ((buffer[0]&0x80)==0x00) { bytes=1; return buffer[0]; } //ASCII character
	//look for multi byte headers
	//longest throws 5+2+2+2 bits, so int32 is more than enough to hold a 4 byte utf8 codepoint
	//if a utf8 character is broken (early 0 termination though string buffer size),
	// direct access would throw an array oob, but with a look that can be cought for no-thorw
	else if ((buffer[0]&0xF8)==0xF0) { cp=buffer[0]&0x07;bytes=4; }
	else if ((buffer[0]&0xF0)==0xE0) { cp=buffer[0]&0x0F;bytes=3; }
	else if ((buffer[0]&0xE0)==0xC0) { cp=buffer[0]&0x1F;bytes=2; }
	//else if ((buffer[0]&0xC0)==0x80) would be continuation; ThrowError: invalid MB char or within MB sequence?
	else return 0; //not MB, we done
	for(int i=1;i<bytes;i+=1) {
		if ((buffer[i]&0xC0)!=0x80) { bytes=0; return 0; } //MB sequence terminated early, probably by \0 - should throw error?
		cp = ((cp<<6)|(buffer[i]&0x3F));
	}
	return cp;
}
/**
 * Retrieve the index of the previous UTF8 char. If within MB char, seeks to start
 * of character.
 * @param buffer string to rev search
 * @param offset offset to start from
 * @return index of prev MB char
 */
int GetPreviousCharMB(const char[] buffer, int offset) {
	if (offset <= 0) return 0;
	int pos=offset-1;
	if ((buffer[pos]&0x80)==0x00) return pos; //ascii char
	while (pos > 0 && ((buffer[pos]&0xC0)==0x80)) pos-=1; //rev continuations
	return pos;
}
/**
 * Check the next codepoint for a space, return the width of the space if true.
 * Might look like a wtf moment, but TF2 acutally renders e.g. EM-Spaces correctly.
 * @param buffer - charptr[at] for utf8 string (sm default)
 * @param bytes - output width of char in bytes (reguardless of return)
 * @param countNonSpaces - usually this is true, counts fees, tabs and vertical separators
 *   if csgo is detected, control characters are ignored automatically.
 * @return true if next codepoint is in UnicodeCategory.SpaceSeparator as listed
 *  here https://docs.microsoft.com/de-de/dotnet/api/system.char.iswhitespace?view=net-6.0
 *  line separators, paragraph separators and control characters (<32) are ignored (false).
 */
bool IsCharMBSpace(const char[] buffer, int& bytes=0, bool countNonSpaces=true) {
	switch (GetCodePoint(buffer, bytes)) {
		case 0x20, 0x00A0, 0x1680, 0x2000, 0x2001, 0x2002,
			0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008,
			0x2009, 0x200A, 0x202F, 0x205F, 0x3000:
			return true;
		case 0x09, 0x0A, 0x0B, 0x0C, 0x0D:
			return !g_bIsCSGOColors && countNonSpaces;
		case 0x0085, 0x2028, 0x2029:
			return countNonSpaces;
		default: return false;
	}
}
/** @return true if changed */
bool TrimStringMB(char[] buffer) {
	int inlen=strlen(buffer), from, to, tmp, tmp2;
	if (inlen == 0) return false;
	//find first non-space
	while (from < inlen && buffer[from] && IsCharMBSpace(buffer[from], tmp) && tmp) {
		from += tmp;
	}
	//find last non-space
	tmp = inlen; //starts post!
	to = inlen; //assume no space at end
	do {
		tmp = GetPreviousCharMB(buffer, tmp);
		if (IsCharMBSpace(buffer[tmp], tmp2) && tmp2) to = tmp;
		else break;
	} while (to>from);
	//cut
	int len=to-from;//+\0
	if (len <= 0) {
		buffer[0]=0; //nothing remains
		return inlen != 0;
	}
	if (len>inlen) ThrowError("Unexpected string expansion"); //how did we get here?
	if (len != inlen) {
		char[] trimmed = new char[len+1];
		strcopy(trimmed, len+1, buffer[from]);//make a trimmed copy
		strcopy(buffer, inlen+1, trimmed); //copy back, has to have had at least inlen+1 bytes size
		return true;
	} else return false;
}
/**
 * source length is unchecked!
 * copy up to length number of bytes from source[sourceoffset] to dest[destoffset], accounting for destsize
 * @return number of bytes copied
 */
int copyNchars(char[] dest, int destsize, int destoffset, const char[] source, int sourceoffset, int length) {
	int maxlen = destsize-destoffset-1;
	if (maxlen <= 0 || length <= 0) return 0;
	if (length > maxlen) length = maxlen;
	strcopy(dest[destoffset], length+1, source[sourceoffset]);
	return length;
}
/**
 * For a CFormated string, no color tags, only color codes.
 * This will parse through the string and drop any duplicate color.
 *
 * This is to save bytes for the already limited space, even processing and
 * skipping over non-ascii spaces.
 */
void CollapseColors(char[] buffer, int maxsize) {
	//for checks i guess
	int len = strlen(buffer);
	//white space buffer
	int wswrite;
	char spaces[MCP_MAXLENGTH_INPUT];
	//last found color
	bool cflag;
	char color[12];
	//write point and temps
	int write, tmp;
	//process string
	for (int read; read < len; read+=1) {
		if ( (tmp=GetNativeColor(buffer[read], color, sizeof(color))) ) {
			read += tmp-1;
			cflag = true; //we want to write a color
		} else if ( buffer[read] < 32 ) { //non-printable no-color, skip from input
			/* nop */
		} else if ( cflag && IsCharMBSpace(buffer[read], tmp) ) { //seek through spaces if in color mode
			wswrite += copyNchars(spaces, sizeof(spaces), wswrite, buffer, read, tmp);
			read += tmp-1; //dont double read MB char bytes
		} else { //we are in printable character territory
			char c = buffer[read]; //read fisrt because spaces/colors can push a 0 under the read cursor
			if (wswrite) {
				strcopy(buffer[write], maxsize-write, spaces);
				write += wswrite;
				wswrite = 0;
			}
			if (cflag) {
				strcopy(buffer[write], maxsize-write, color);
				write += strlen(color);
				cflag = false;
			}
			buffer[write] = c;
			write += 1;
		}
	}
	//there seem to have been a bunch of trailing spaces, append last color again for strcats
	if (cflag) {
		strcopy(buffer[write], maxsize-write, color);
		write += strlen(color);
	}
	buffer[write]=0; //terminate at collapsed position

}
