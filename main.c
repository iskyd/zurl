#include<curl/curl.h>

int main() {
  curl_global_init(CURL_GLOBAL_DEFAULT);
  return 0;  
}
