#if T == double || U == double
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#endif

__kernel
void transpose( __global T * out, __global const T * in,
                dim_type iDim0, dim_type iDim1,
                dim_type iStride1, dim_type iStride2,
                dim_type offset,
                dim_type nonBatchBlkSize)
{
    __local T shrdMem[TILE_DIM*(TILE_DIM+1)];


    const dim_type shrdStride = TILE_DIM+1;
    // create variables to hold output dimensions
    const dim_type oDim0 = iDim1;
    const dim_type oDim1 = iDim0;

    // calculate strides
    const dim_type oStride1    = oDim0;

    dim_type lx      = get_local_id(0);
    dim_type ly      = get_local_id(1);

    // batch based block Id
    dim_type batchId = get_group_id(0) / nonBatchBlkSize;
    dim_type blkIdx_x= (get_group_id(0)-batchId*nonBatchBlkSize);

    // calculate global indices
    dim_type gx      = lx + TILE_DIM * blkIdx_x;
    dim_type gy      = ly + TILE_DIM * get_group_id(1);

    // offset in and out based on batch id
    // also add the subBuffer offsets
    in  += batchId * iStride2 + offset;
    out += batchId * oDim0 * oDim1;

    for (dim_type repeat = 0; repeat < TILE_DIM; repeat += get_local_size(1)) {
        dim_type gy_ = gy+repeat;
        if (gx<iDim0 && gy_<iDim1)
            shrdMem[(ly+repeat)*shrdStride+lx] = in[gy_*iStride1+gx];
    }
    barrier(CLK_LOCAL_MEM_FENCE);

    gx          = lx + TILE_DIM * get_group_id(1);
    gy          = ly + TILE_DIM * blkIdx_x;

    for (dim_type repeat = 0; repeat < TILE_DIM; repeat += get_local_size(1)) {
        dim_type gy_ = gy+repeat;
        if (gx<oDim0 && gy_<oDim1)
            out[gy_*oStride1+gx] = shrdMem[lx*shrdStride+ly+repeat];
    }
}