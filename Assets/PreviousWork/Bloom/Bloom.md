### Bloom

算法：

- Bloom Pyramid:降采样，生成mipmapClain，并逐级实行分离高斯模糊; 逐级上采样，叠加模糊
- Bloom参数：阈值（Knee 曲线），强度 ；Pre-filter Pass  - 淡化firefiles，扩大至6x6 Box Filter  ；Bloom模式：叠加、散射；


效果：

![bloom-additive](C:/Users/Gesetztafel/Desktop/jianli/2022-春招/bloom-additive.JPG)

![bloom-scatter](C:/Users/Gesetztafel/Desktop/jianli/2022-春招/bloom-scatter.JPG)

up：additive;down:Scatter

**Further Work**

[Jimenez 14] better DownSample& Upsample filter?[Mittring 12]Dirt Mask?

Per-Object？Luma？可拾色?Mobile Optimization；