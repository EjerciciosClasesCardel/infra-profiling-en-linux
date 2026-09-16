// Cuatro hilos que trabajan tiempos distintos: el hilo h se ocupa durante
// h + 1 segundos y después termina. Sirve para mirar el programa desde
// afuera con ps y top mientras corre.
#include <chrono>
#include <cstdio>
#include <omp.h>

using namespace std::chrono;

int main() {
  omp_set_num_threads(4);
  double basura = 0;
#pragma omp parallel reduction(+ : basura)
  {
    int h = omp_get_thread_num();
    auto fin = steady_clock::now() + seconds(h + 1);
    while (steady_clock::now() < fin)
      for (int k = 0; k < 1000; k++) basura += k * 0.5;
  }
  printf("listo %.0f\n", basura);
  return 0;
}
