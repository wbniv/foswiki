# Makefile for NativeTWikiSearch module
use ExtUtils::MakeMaker;
WriteMakefile(
   NAME => 'NativeTWikiSearch',
   OBJECT => 'NativeTWikiSearch.o cgrep.o',
   LIBS => [ '-lpcre' ],
   CCFLAGS => "-g",
   LD => "gcc",
   OBJ_EXT => ".o",
   LDFROM => '$(OBJECT) -lpcre',
);
