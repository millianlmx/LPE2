#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) 
{
#ifdef TARGET
    printf("Hello %s\n", TARGET);
#else
    printf("Hello World\n");
#endif
  return 0;
}
