#help_index "God"

#define GOD_BAD_BITS	4
#define GOD_GOOD_BITS	24

public class CGodGlbls
{
  U8	**words,
	*word_file_mask;
  I64	word_fuf_flags,
	num_words;
  CFifoU8 *fifo;
  CDC	*doodle_dc;
  I64	doodle_ch;
  CFifoU8 *doodle_fifo;
  Bool	doodle_done;

  //AntichristOS: The Adversary.  See $LK,"::/Adam/God/AdvNotes.DD"$.
  U8	**rev_words;	//Backmasked vocab, same order as words.
  I64	*rev_match,	//Idx of the word that is the reversal, or -1.
	num_backmasks,	//Words whose reversal is another word.
	num_palindromes;//Words whose reversal is the same word.
  Bool	doodle_hell;	//GodDoodleSprite() in hellfire colors.
} god;
MemSet(&god,0,sizeof(CGodGlbls));
god.doodle_fifo	=FifoU8New(2048*8);
god.fifo	=FifoU8New(2048*8);

extern U0 GodBiblePassage(I64 num_lines=20);
extern U0 GodBitsIns(I64 num_bits,I64 n);
extern U0 GodDoodle(U8 *hex=NULL);
extern U0 GodSong();
extern U0 GodWord(I64 bits=17);
extern U0 AdversaryDoodle(U8 *hex=NULL);
extern U0 AdversaryPassage(I64 num_lines=20);
extern U0 AdversaryWord(I64 bits=17);
extern U0 DiabolusSong();
