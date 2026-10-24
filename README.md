# Angband-Next #

My attempt at a port of Angband for the **ZX Spectrum Next** in assembly code with lots of help from Claude Code 

Reference source used - Angband V1.2 PC port C files by Charles Teague.

## Character ##
Created at the start of each game: choose a race (10), sex and class (6, as the race allows), roll stats (space rolls again, Enter accepts), then type a name (Caps Shift+0 deletes). Race and class set the hit die, base to-hit, stealth, infravision and experience factor; stats give to-hit, damage, armour class, hit points per level and blows. The class's starting kit comes from player_init[] (warriors carry a Potion of Berserk Strength, priests one of Healing), minus torches and books the game can't use yet. Background history isn't generated (social class is taken as 50 for starting gold).

## Controls ##
h j k l y u b n (Angband roguelike keys) or cursor keys 5 6 7 8. Walk into a closed door to open it (picking its lock if it has one), or into a monster to attack it; walking onto an item picks it up; walking onto a store's number goes in (p purchase, s sell, at home g get and d drop, space leaves). s searches for a turn (staying still). R (Caps Shift+R) rests: a number of turns, or Enter for as long as needed. Caps Shift with a movement letter (HJKLYUBN) runs that way. > (Symbol Shift+T) / < (Symbol Shift+R) take stairs.

C (Caps Shift+C) shows the character sheet. Symbol Shift+X (the C's ^X) saves the game and goes back to the title; pressing a key there carries on from the save. F (Caps Shift+F) fills a lantern from a flask of oil. D (Caps Shift+D) disarms a trap you've found, T (Caps Shift+T) tunnels through rubble or rock; both ask for a direction. v throws or fires something from the pack in a direction. Doors: o opens (picks a lock), c closes, f forces (bashes) a door or a monster with your shield, S (Caps Shift+S) jams a closed door with an iron spike; each asks for a direction. x looks around (a direction, or 5 all round), M (Caps Shift+M) shows the whole map, W (Caps Shift+W) moves the view about (locate), Symbol Shift+P shows the last messages (^P), / (Symbol Shift+V) identifies a symbol, % (Symbol Shift+5) is Self Knowledge. Q (Caps Shift+Q) quits, or retires once you've won.

### Items ###
i inventory, e equipment, w wear/wield, t take off, q quaff, r read, z aim a wand, Z (Caps Shift+Z) use a staff, a activate a rod, A (Caps Shift+A) activate an artifact, m cast a spell, p recite a prayer, P (Caps Shift+P) browse a book, G (Caps Shift+G) learn new spells, E (Caps Shift+E) eat, d drop, g pick up. Choose items by letter; space cancels. Directions: 1-9 or hjklyubn.


Source based on can be located here : https://rephial.org/release/pcangband-1.2
<pre>/* Original copyright message follows.                                   */
/*   ANGBAND Version 4.8	COPYRIGHT (c) Robert Alan Koeneke      	*/
/*                                      		        	 */
/*	 I lovingly dedicate this game to hackers and adventurers	 */
/*	 everywhere...						         */
/*								       	 */
/*		                                                         */
/*	 Designer and Programmer : Robert Alan Koeneke		    	 */
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
/*									 */ </pre>
