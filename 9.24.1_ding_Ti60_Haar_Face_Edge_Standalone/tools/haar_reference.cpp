#include <cstdint>
#include <cmath>
#include <fstream>
#include <vector>
#include <iostream>
#include <string>
#include "../model/model_arrays.h"
using namespace std;
vector<uint64_t> ii,ss;
int W,H;
uint64_t rect(const vector<uint64_t>&a,int x,int y,int w,int h){return a[y*W+x]-a[y*W+x+w]-a[(y+h)*W+x]+a[(y+h)*W+x+w];}
int classify(int x,int y){
 auto m=rect(ii,x,y,24,24),s=rect(ss,x,y,24,24);
 int64_t v=int64_t(s*576)-int64_t(m*m); int64_t sd=v>0?(int64_t)sqrt((double)v):1;
 if(sd<1)sd=1; int n=0;
 const int* rr[]={rectangles_array0,rectangles_array1,rectangles_array2,rectangles_array3,rectangles_array4,rectangles_array5,rectangles_array6,rectangles_array7,rectangles_array8,rectangles_array9,rectangles_array10,rectangles_array11};
 const int* ww[]={weights_array0,weights_array1,weights_array2};
 for(int stage=0;stage<25;stage++){
  int sum=0;
  for(int j=0;j<stages_array[stage];j++,n++){
   int64_t f=0;for(int k=0;k<3;k++)if(ww[k][n])f+=(int64_t)rect(ii,x+rr[4*k][n],y+rr[4*k+1][n],rr[4*k+2][n],rr[4*k+3][n])*ww[k][n];
   sum+=f>=int64_t(tree_thresh_array[n])*sd?alpha2_array[n]:alpha1_array[n];
  }
  if(sum*5<2*stages_thresh_array[stage])return stage;
 }
 return 25;
}
int main(int argc,char**argv){
 if(argc<4)return 2; W=stoi(argv[2]);H=stoi(argv[3]);vector<unsigned char> img(W*H);ifstream f(argv[1],ios::binary);f.read((char*)img.data(),img.size());if(f.gcount()!=img.size())return 3;
 ii.resize(W*H);ss.resize(W*H);
 for(int y=0;y<H;y++){uint64_t a=0,b=0;for(int x=0;x<W;x++){int p=img[y*W+x];a+=p;b+=p*p;ii[y*W+x]=a+(y?ii[(y-1)*W+x]:0);ss[y*W+x]=b+(y?ss[(y-1)*W+x]:0);}}
 int count=0,step=argc>4?stoi(argv[4]):2;
 for(int y=(argc>6?stoi(argv[6]):0);y+24<H;y+=step)for(int x=(argc>5?stoi(argv[5]):0);x+24<W;x+=step)if(classify(x,y)==25){cout<<x<<","<<y<<",24,24\n";count++;}
 cerr<<"PASS reference completed: "<<count<<" detections\n";return 0;
}
