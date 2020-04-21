// vim: sw=4 ts=4 et
// han-carlson simulation

#include <stdio.h>
#include <math.h>
#include <stdlib.h>

void main(int argc, char *argv[])
{
    int xlen = 8;
    if (argc > 1)
    {
        xlen = atoi(argv[1]);
        printf("%d bits, %d stages\n", xlen, (int)log2(xlen)+1);
    }
    printf("[black|grey|pass][bit]:(stage,bit)\n");

    for (int j=0; j<=log2(xlen); j++)
    {
        printf("Stage %2d: ", j);
        for (int i=xlen-1; i>=0; i--)
        {
            // black cells
            if (
                ((i % 2) == 1)
                && ((i+1)/2 > pow(2,j))
                //&& ((i+1)/2 >= pow(2,j-1))
               )
            {
                printf("b:%2d=>(%2d,%2d) ",i,j-1,i-(int)pow(2,j));
            }
            // grey cells 1
            if (
                ((i % 2) == 1)  // even bits (base 0)
                && ((i+1)/2 <= pow(2,j)) // less than halfway back from the jth power of 2
                && (i >= pow(2,j)) // less than halfway again back from there
               )
            {
                printf("g:%2d=>(%2d,%2d) ",i,j-1,i-(int)pow(2,j));

            }
            // grey cells end
            if (
                // bottom row
                ((i % 2) == 0) // odd bits
                && (j == log2(xlen)) // bottom row
                && (i > 0) // NOT the first bit
               )
            {
                printf("g:%2d=>(%2d,%2d) ",i,j-1,i-1);
            }
            if (
                // all rightward of last grey cell
                // OR even bits not on last row
                ((i < pow(2,j) || (i % 2 == 0)) && (j < log2(xlen)))
                // odd bits and bit 0 on last row
                || ((i % 2 == 1 || i == 0) && (j == log2(xlen)))
               )
            {
                printf("p:%2d          ",i);
            }
        }
        printf("\n");
    }
}
