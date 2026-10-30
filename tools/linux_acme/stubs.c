#include <stdio.h>
#include <stdbool.h>
void PDBInit(void){}
void PDBAddFileLineToAddr(const int a,const char*f,const int l,const int z,const bool p){}
void PDBSave(FILE*fp){}
int GetLabelAge(const int c,const char*l,const char*f,int n,int z){return 1;}
int IsLabelSameAsLastValue(const int v,const char*l,const char*f,int n,int z){return 1;}
int GetLabelNumberDifferences(const char*l,const char*f,int n,int z){return 0;}
#include <strings.h>
int _stricmp(const char*a,const char*b){return strcasecmp(a,b);}
int RunScript_Python(const char*p,const char*n,const char*py){return 0;}
void PDBSave2(FILE*fp){}
void SetDevice(const int d){}
#include <string.h>
char*_strdup(const char*s){return strdup(s);}
void SortFile(const char*a,const char*b){}
