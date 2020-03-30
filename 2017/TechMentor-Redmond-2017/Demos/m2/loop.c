/*
        Author:                 Anthony E. Nocentino
        Email:                  aen@centinosystems.com
        Description:            Simple program to write to both stdout and stderr. Loops. This allows us to easily generate
				IO for redirection.
*/

#include <stdio.h>

int main()
{
        int i;
        i = 0;
        
        for ( ; ; )
        {
                fprintf(stdout, "stdout: %d\n", i);
                fprintf(stderr, "stderr: %d\n", i);
                sleep(1);
                i++;
        }
}
