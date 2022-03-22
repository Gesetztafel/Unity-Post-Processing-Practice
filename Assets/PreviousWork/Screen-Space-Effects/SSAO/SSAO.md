### SSAO

**算法**

- AO Pass：[McGuire 12] Scalable AO ；Alchemy AO算法,；Sample分布：Vogel圆盘分布，交错梯度噪声；
- Blur Pass：边缘感知空间过滤，高斯核，水平，竖直模糊通道分离；
- 性能优化：DownSampling Pass: depth; halfRef ;UpSampling Pass ;  

#### Further Work

**Better UpScaling**

Better Downsampling && Upsampling with depth aware:
checkerboard Pattern?Nearest depth sampling? 

**更多的性能优化：** 内存带宽瓶颈

[Bavoil 14] Deinterleaved Texture & [McGuire 12]Depth & Normal Mipmap Clain

**[Jimenez  16]GTAO?GTSO?** **Multi-Bounce**

**Denoising ?** Spatial Filtering+Temporal

**Bent Normal?**

**Sample Noise ?**

**Near-Field ？ Thin Occluder ?**

**SSAO效果：**

![ssao halfRes](C:/Users/Gesetztafel/Desktop/jianli/2022-春招/ssao halfRes.JPG)

Test screen：Crytek-Sponza;

SSAO settings:sample counts:16,Radius World 1.0 ,Contrast 2.5,HalfRes;



## References:

...