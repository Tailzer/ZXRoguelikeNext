My attempt at a port of Angband for the ZX Spectrum Next in assembly code with lots of help from Claude Code, Angband V1.2 PC port C files by Charles Teague used at reference.


Source based on can be located here : https://rephial.org/release/pcangband-1.2

/* Original copyright message follows. */

/* ANGBAND Version 4.8	COPYRIGHT (c) Robert Alan Koeneke		*/
/*									 */
/*	 I lovingly dedicate this game to hackers and adventurers	 */
/*	 everywhere...							 */
/*									 */
/*									 */
/*	 Designer and Programmer : Robert Alan Koeneke			 */
/*				   University of Oklahoma		 */
/*									 */
/*	 Assistant Programmers	 : Jimmey Wayne Todd			 */
/*				   University of Oklahoma		 */
/*									 */
/*				   Gary D. McAdoo			 */
/*				   University of Oklahoma		 */
/*									 */
/*	 UNIX Port		 : James E. Wilson			 */
/*				   UC Berkeley				 */
/*				   wilson@ernie.Berkeley.EDU		 */
/*				   ucbvax!ucbernie!wilson		 */
/*									 */
/*	 MSDOS Port		 : Don Kneller				 */
/*				   1349 - 10th ave			 */
/*				   San Francisco, CA 94122		 */
/*				   kneller@cgl.ucsf.EDU			 */
/*				   ...ucbvax!ucsfcgl!kneller		 */
/*				   kneller@ucsf-cgl.BITNET		 */
/*									 */
/*	 BRUCE ANGBAND		 : Christopher Stuart			 */
/*				   Monash University			 */
/*				   Melbourne, Victoria, AUSTRALIA	 */
/*				   cjs@moncsbruce.oz			 */
/*									 */
/*	 ANGBAND may be copied and modified freely as long as the above	 */
/*	 credits are retained.	No one who-so-ever may sell or market	 */
/*	 this software in any form without the expressed written consent */
/*	 of the author Robert Alan Koeneke.				 */
/*									 */
