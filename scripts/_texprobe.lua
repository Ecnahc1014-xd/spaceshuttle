function Start()
    local scene = Scene(); scene:CreateComponent("Octree")
    local cn=scene:CreateChild("C"); cn.position=Vector3(0,0,-10); cn:LookAt(Vector3(0,0,0))
    local cam=cn:CreateComponent("Camera"); cam.orthographic=true; cam.orthoSize=6
    renderer:SetViewport(0, Viewport:new(scene,cam))
    local ln=scene:CreateChild("L"); ln.position=Vector3(0,0,-8); ln:LookAt(Vector3(0,0,0))
    local light=ln:CreateComponent("Light"); light.lightType=LIGHT_DIRECTIONAL; light.brightness=1.3

    -- 软圆纹理
    local N=32; local img=Image(); img:SetSize(N,N,4)
    local c=(N-1)*0.5
    for y=0,N-1 do for x=0,N-1 do
        local d=math.sqrt((x-c)^2+(y-c)^2)/c
        local a=math.max(0,math.min(1,1-math.max(0,(d-0.55)/0.45)))
        img:SetPixel(x,y,Color(1,1,1,a))
    end end
    -- 读回中心和角落 alpha
    local pc=img:GetPixel(16,16); local pe=img:GetPixel(1,1)
    print(string.format("IMG center.a=%.2f edge.a=%.2f", pc.a, pe.a))

    local function makeSet(x, tex, rr,gg,bb)
        local pn=scene:CreateChild("B"..tostring(x))
        local bs=pn:CreateComponent("BillboardSet"); bs:SetNumBillboards(1); bs.relative=false
        local m=Material:new(); m:SetTechnique(0,cache:GetResource("Technique","Techniques/DiffVCol.xml"))
        m:SetTexture(TU_DIFFUSE, tex); m:SetShaderParameter("MatDiffColor",Variant(Color(1,1,1,1)))
        bs:SetMaterial(m)
        local b=bs:GetBillboard(0); b.enabled=true; b.position=Vector3(x,0,0); b.size=Vector2(2,2)
        b.color=Color(rr,gg,bb,1)
        bs:Commit()
    end
    local tex=Texture2D:new(); tex:SetData(img,false); tex:SetSRGB(true)
    makeSet(-2, tex, 1,0.3,0.3)          -- 软圆纹理 + 红 vertex color
    -- 1px 白纹理对照
    local w=Image(); w:SetSize(1,1,4); w:SetPixel(0,0,Color(1,1,1,1))
    local wt=Texture2D:new(); wt:SetData(w,false); wt:SetSRGB(true)
    makeSet(2, wt, 1,0.3,0.3)           -- 1px 白纹理 + 红 vertex color
end
