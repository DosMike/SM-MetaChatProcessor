#if defined _metachatcommon_utilities
#endinput
#endif
#define _metachatcommon_utilities

#include <morecolors>

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
stock bool ParseChatColor(const char[] color, char[] output, int maxsize, int author) {
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
stock bool RemoveTextColors(char[] message, int maxsize, bool removeTags=true) {
	int strlenStart = strlen(message);
	if (removeTags) CRemoveTags(message, maxsize);
	int read,write;
	if (GetEngineVersion()==Engine_CSGO) {
		for (;message[read] && read < maxsize;read+=1) {
			if (0 < message[read] <= 0x32) continue; //just skip all control chars, they have no business here
			if (read!=write)
				message[write] = message[read];
			write+=1;
		}
	} else {
		for (;message[read] && read < maxsize;read+=1) {
			if (message[read]==7) { read+=6; continue; } //skip following RRGGBB as well
			else if (message[read]==8) { read+=8; continue; } //skip following RRGGBBAA as well
			else if (0 < message[read] <= 0x32) continue; //just skip all control chars, they have no business here
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
stock int StringStartsWithColor(const char[] buffer) {
	int at=0;
	for (;buffer[at] != 0;at+=1) {
		if (0x01 <= buffer[at] < ' ')
			return at;
		else if (buffer[at] > ' ')
			return -1;
	}
	return -1;
}
/**
 * normal mode gets the color only if it is in from of any printable characters (>32)
 * post mode is intended to get the color a concatinated string would inherit
 */
stock bool GetStringColor(const char[] buffer, char[] color, int bufsize, bool post=false) {
	int at=-1;
	if (post) {
		for (int i=strlen(buffer)-1; i>=0; i-=1) {
			if (buffer[i] < ' ') {
				at=i;break;
			}
		}
	} else {
		at = StringStartsWithColor(buffer);
	}
	if (at < 0) return false;
	if (g_bIsCSGOColors || buffer[at] < 7 || 8 < buffer[at] < ' ' ) {
		strcopy(color, 2>bufsize?bufsize:2, buffer[at]);
	} else if (buffer[at] == 7) {
		strcopy(color, 8>bufsize?bufsize:8, buffer[at]);
	} else if (buffer[at] == 7) {
		strcopy(color, 8>bufsize?bufsize:8, buffer[at]);
	} else ThrowError("Invalid color at character");
	return true;
}

/**
 * Get the native color code at the start of the given buffer
 * @param buffer - search text, user charptr[at] for offsets
 * @param out - color code output
 * @param maxlen - output size
 * @return length of color code or 0 if not a color
 */
stock int GetNativeColor(const char[] buffer, char out[]="", int maxlen=0) {
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
 * @param bytes, width of the character returned, 0 for broken MB chars
 * @return codepoint or 0 if a MB character is broken
 */
stock int GetCodePoint(const char[] buffer, int& bytes=0) {
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
stock bool IsCharMBSpace(const char[] buffer, int& bytes=0, bool countNonSpaces=true) {
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
stock bool TrimStringMB(char[] buffer) {
	int inlen=strlen(buffer), from, to, tmp, tmp2;
	//find first non-space
	while (buffer[from] && IsCharMBSpace(buffer[from], tmp) && tmp) {
		from += tmp;
	}
	//find last non-space
	tmp2 = from;
	while (buffer[tmp2]) {
		if (!IsCharMBSpace(buffer[tmp2], tmp)) {
			to = tmp2+tmp; //from + char width -> to = post
		} else if (!tmp) break;
		tmp2 += tmp;
	}
	//cut
	int len=to-from;//+\0
	if (len <= 0) buffer[0]=0; //nothing remains
	if (len>inlen) len=inlen; //how did we get here?
	Format(buffer, len+1, "%s", buffer[from]);
}
/** 
 * source length is unchecked!
 * copy up to length number of bytes from source[sourceoffset] to dest[destoffset], accounting for destsize
 * @return number of bytes copied
 */
stock int copyNchars(char[] dest, int destsize, int destoffset, const char[] source, int sourceoffset, int length) {
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
stock void CollapseColors(char[] buffer, int maxsize) {
	//for checks i guess
	int len = strlen(buffer);
	//white space buffer
	int wswrite;
	char spaces[MAXLENGTH_INPUT];
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
	
}
