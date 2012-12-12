//Since assemblers require newlines use the » character to signify
//a new line. After the preprocessor is run it will be replaced with a new line

#define SPACE(words)\
:spacemaker»\
org spacemaker+words

#define DIM(name, words)»\
:##name »\
SPACE(words)»\
:##name##_end»
