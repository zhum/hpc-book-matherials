#include "mpi.h"
#include <stdio.h>
#include <math.h>
#define NINT 1000000
#define COUNT 100000

/*
 * Compile it: mpicc -o mpi-pi sample-mpi-pi-calc.c
 * Run it:     mpirun --machilefile ... -n NN ./mpi-pi
 *
 */

double f( double a) {
  return (4.0 / (1.0 + a*a));
}

int main( int argc, char *argv[] )
{
  int done = 0, n, myid, numprocs, i;
  double PI25DT = 3.141592653589793238462643;
  double mypi, pi, h, sum, x;
  double startwtime=0.0, endwtime;
  int namelen;
  char processor_name[MPI_MAX_PROCESSOR_NAME];
  int rep;
  double *mem[1000];

  MPI_Init(&argc,&argv);
  MPI_Comm_size(MPI_COMM_WORLD,&numprocs);
  MPI_Comm_rank(MPI_COMM_WORLD,&myid);
  MPI_Get_processor_name(processor_name,&namelen);
  fprintf(stderr, "Process %d on %s\n",
          myid, processor_name);
  n = 0;
  while (!done) {
    if (myid == 0) {
      if (n==0) n=NINT; else n=0;
      startwtime = MPI_Wtime();
    }
    MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);
    if (n == 0)
        done = 1;
    else {
      for(rep=0; rep<COUNT;++rep){
        h = 1.0 / (double) n;
        sum = 0.0;
        for (i = myid + 1; i <= n; i += numprocs) {
          x = h * ((double)i – 0.5);
          sum += f(x);
        }
        mypi = h * sum;
        MPI_Reduce(&mypi, &pi, 1, MPI_DOUBLE, \
                   MPI_SUM, 0, MPI_COMM_WORLD);
        if (myid == 0) {
          printf("pi is approximately %.16f,"
                 " Error is %.16f\n",
                  pi, fabs(pi – PI25DT));
          endwtime = MPI_Wtime();
          printf("wall clock time = %f\n",
                 endwtime-startwtime);
        }
      }
    }
  }
  MPI_Finalize();
  return 0;
}

