#include <time.h>
#include <sys/time.h>
#include <vector>
#include <string>
#include <iostream>

#include <thrust/device_vector.h>

#include <utilities/error_utils.hpp>
#include <gtest/gtest.h>

#include <tests/utilities/cudf_test_utils.cuh>

#include <cuspatial/soa_readers.hpp> 
#include <cuspatial/hausdorff.hpp> 
#include <cuspatial/shared_util.h> 
#include "hausdorff_util.h" 

#include <tests/utilities/cudf_test_utils.cuh>
#include <tests/utilities/cudf_test_fixtures.h>

struct is_true
{
	__host__ __device__
	bool operator()(const thrust::tuple<double, double>& t)
	{
		double v1= thrust::get<0>(t);
		double v2= thrust::get<1>(t);
		return(fabs(v1-v2)>0.01);
	}
};


struct HausdorffTest2 : public GdfTest 
{
    
    gdf_column pnt_x,pnt_y,cnt;
    size_t free_mem = 0, total_mem = 0;
    
    void set_initialize(const char *point_fn, const char *cnt_fn)
    {
    
      cudaMemGetInfo(&free_mem, &total_mem);
      std::cout<<"GPU total_mem="<<total_mem<<std::endl;
      std::cout<<"beginning GPU free_mem="<<free_mem<<std::endl;
      
      struct timeval t0,t1;
      gettimeofday(&t0, NULL);
      
      cuSpatial::read_pnt_xy_soa(point_fn,pnt_x,pnt_y);
      cuSpatial::read_uint_soa(cnt_fn,cnt);
      
      gettimeofday(&t1, NULL);
      float data_load_time=calc_time("point/cnt data loading time=", t0,t1);
      CUDF_EXPECTS(pnt_x.size>0 && pnt_y.size>0 && cnt.size>=0,"invalid # of points/trajectories");
      CUDF_EXPECTS(pnt_x.size==pnt_y.size, "x and y columns must have the same size");
      CUDF_EXPECTS(pnt_y.size >=cnt.size ,"a point set must have at least one point");      
    }
};

TEST_F(HausdorffTest2, hausdorfftest)
{
    std::string point_fn =std::string("/home/jianting/trajcode/locust256.coor");
    std::string cnt_fn =std::string("/home/jianting/trajcode/locust256.objcnt");
    
    this->set_initialize(point_fn.c_str(),cnt_fn.c_str());
    
    struct timeval t0,t1,t2;
    gettimeofday(&t0, NULL);
    
    gdf_column dist1=cuSpatial::hausdorff_distance(this->pnt_x,this->pnt_y, this->cnt);         
    assert(dist1.data!=NULL);
    gettimeofday(&t1, NULL);
    float gpu_hausdorff_time1=calc_time("GPU Hausdorff Distance time 1......",t0,t1);
    
    gdf_column dist2=cuSpatial::hausdorff_distance(this->pnt_x,this->pnt_y, this->cnt);         
    assert(dist2.data!=NULL);
    gettimeofday(&t2, NULL);
    float gpu_hausdorff_time2=calc_time("GPU Hausdorff Distance time 2......",t1,t2);
  
    CUDF_EXPECTS(dist1.size==dist2.size ,"output of the two rounds needs to have the same size");
       
    int set_size=this->cnt.size;
    int num_pair=dist1.size;
    assert(num_pair==set_size*set_size);
    std::cout<<"num_pair="<<num_pair<<std::endl;
    
if(1)
{
	  double *data1=NULL,*data2=NULL;
	    RMM_TRY( RMM_ALLOC((void**)&data1, sizeof(double)*num_pair, 0) );
    RMM_TRY( RMM_ALLOC((void**)&data2, sizeof(double)*num_pair, 0) );
    assert(data1!=NULL && data2!=NULL);
    cudaMemcpy(data1,dist1.data ,num_pair*sizeof(double) , cudaMemcpyDeviceToDevice);
    cudaMemcpy(data2,dist2.data ,num_pair*sizeof(double) , cudaMemcpyDeviceToDevice);
    
    thrust::device_ptr<double> d_dist1_ptr=thrust::device_pointer_cast(data1);
    thrust::device_ptr<double> d_dist2_ptr=thrust::device_pointer_cast(data2);
    auto it=thrust::make_zip_iterator(thrust::make_tuple(d_dist1_ptr,d_dist2_ptr));
    	
	int this_cnt=thrust::copy_if(it,it+num_pair,it,is_true())-it;	
	thrust::copy(d_dist1_ptr,d_dist1_ptr+this_cnt,std::ostream_iterator<double>(std::cout, " "));
	std::cout<<std::endl<<std::endl;
	thrust::copy(d_dist2_ptr,d_dist2_ptr+this_cnt,std::ostream_iterator<double>(std::cout, " "));
	std::cout<<std::endl<<std::endl;
	
	if(this_cnt==0)
		std::cout<<"Two rounds GPU results are identical...................OK"<<std::endl;     	
	else
		std::cout<<"Two rounds GPU results diff="<<this_cnt<<std::endl;     	
	RMM_TRY( RMM_FREE(data1, 0) );
	RMM_TRY( RMM_FREE(data2, 0) );
	
}   	
    int num_pnt=this->pnt_x.size;
    double *x_c=new double[num_pnt];
    double *y_c=new double[num_pnt];
    uint *cnt_c=new uint[set_size];
    assert(x_c!=NULL && y_c!=NULL && cnt_c!=NULL);
    cudaMemcpy(x_c,this->pnt_x.data ,num_pnt*sizeof(double) , cudaMemcpyDeviceToHost);
    cudaMemcpy(y_c,this->pnt_y.data ,num_pnt*sizeof(double) , cudaMemcpyDeviceToHost);
    cudaMemcpy(cnt_c,this->cnt.data ,set_size*sizeof(uint) , cudaMemcpyDeviceToHost);
    
    int subset_size=100;
    double *dist_c=NULL;
    hausdorff_test_sequential<double>(subset_size,x_c,y_c,cnt_c,dist_c);
    assert(dist_c!=NULL);
    
    double *dist_h1=new double[num_pair];
    double *dist_h2=new double[num_pair];
    assert(dist_h1!=NULL && dist_h2!=NULL);
    
    cudaMemcpy(dist_h1,dist1.data ,num_pair*sizeof(double) , cudaMemcpyDeviceToHost);
    cudaMemcpy(dist_h2,dist2.data ,num_pair*sizeof(double) , cudaMemcpyDeviceToHost);
    
    int diff_cnt=0, gpu_cnt=0;
    for(int i=0;i<subset_size;i++)
    {
    	for(int j=0;j<subset_size;j++)
    	{
    		int p1=i*subset_size+j;
    		int p2=i*set_size+j;
    		if(fabs(dist_c[p1]-dist_h1[p2])>0.00001)
    		{
    			std::cout<<"cg:("<<i<<","<<j<<") "<<dist_c[p1]<<"  "<<dist_h1[p2]<<std::endl;
    			diff_cnt++;
    		}
      		if(fabs(dist_h1[p2]-dist_h2[p2])>0.00001)
    		{
    			std::cout<<"gg:("<<i<<","<<j<<") "<<dist_h1[p2]<<"  "<<dist_h2[p2]<<std::endl;
    			gpu_cnt++;
    		}
  		
    	}
    }
   
   if(diff_cnt==0)
	std::cout<<"GPU and CPU results are identical...................OK"<<std::endl;     	
    else
	std::cout<<"# of GPU and CPU diffs="<<diff_cnt<<std::endl;     
	
  if(gpu_cnt==0)
	std::cout<<"Two rounds GPU results are identical...................OK"<<std::endl;     	
    else
	std::cout<<"Two rounds GPU results diff="<<gpu_cnt<<std::endl;     	
    
    cudaMemGetInfo(&this->free_mem, &this->total_mem);
    std::cout<<"ending GPU free mem "<<this->free_mem<<std::endl;
}
