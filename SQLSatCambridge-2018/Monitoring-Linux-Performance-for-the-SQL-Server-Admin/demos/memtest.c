#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv)
{
        int64_t size;
        int64_t elements;
        int64_t *mem;
        int64_t i;
        int64_t allocationsize;

        int elementsize;
        elementsize = sizeof(int64_t);

        allocationsize = atoll(argv[1]);                //not safe, just for demonstration
        printf("Memory allocation size: %d\n", allocationsize);

        size = allocationsize * (1024 * 1024);
        elements = size / elementsize;

        printf("Allocating size: %lld elements: %lld: elementsize %lld\n", size, elements, elementsize);

        mem = calloc( elements, elementsize );

        if ( mem == NULL )
        {
                printf("error allocating memory\n");
        }

        for ( i=0; i<elements; i++)
        {
                mem[i] = i;

                if ( i == (elements-1) )
                {
                        printf("wrapping array\n");
                        i = 0;
                }
        }

        free(mem);
}
