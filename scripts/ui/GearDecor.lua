local M = {}
local TAU = math.pi * 2
local function path(ctx,cx,cy,r,n,rot)
 local root=r*0.72; local step=TAU/n; nvgBeginPath(ctx)
 for i=0,n-1 do local a=rot+i*step; nvgLineTo(ctx,cx+math.cos(a)*root,cy+math.sin(a)*root); nvgLineTo(ctx,cx+math.cos(a+step*.24)*r,cy+math.sin(a+step*.24)*r); nvgLineTo(ctx,cx+math.cos(a+step*.76)*r,cy+math.sin(a+step*.76)*r); nvgLineTo(ctx,cx+math.cos(a+step)*root,cy+math.sin(a+step)*root) end
 nvgClosePath(ctx)
end
function M.DrawGear(ctx,cx,cy,r,n,rot,rgb,alpha)
 if r<2 then return end; local a=math.min(255,alpha or 96); nvgSave(ctx); nvgShapeAntiAlias(ctx,1)
 path(ctx,cx+2,cy+3,r+2,n,rot); nvgFillColor(ctx,nvgRGBA(2,8,15,math.floor(a*.8))); nvgFill(ctx)
 path(ctx,cx,cy,r,n,rot); nvgFillColor(ctx,nvgRGBA(rgb[1],rgb[2],rgb[3],math.floor(a*.55))); nvgFill(ctx); nvgStrokeColor(ctx,nvgRGBA(rgb[1],rgb[2],rgb[3],a)); nvgStrokeWidth(ctx,math.max(1.8,r*.08)); nvgStroke(ctx)
 nvgBeginPath(ctx); nvgCircle(ctx,cx,cy,r*.68); nvgStrokeColor(ctx,nvgRGBA(220,250,255,math.floor(a*.8))); nvgStrokeWidth(ctx,math.max(1.5,r*.06)); nvgStroke(ctx)
 nvgBeginPath(ctx); nvgCircle(ctx,cx,cy,math.max(2.4,r*.22)); nvgFillColor(ctx,nvgRGBA(2,8,15,math.floor(a*.95))); nvgFill(ctx); nvgStrokeColor(ctx,nvgRGBA(220,250,255,math.floor(a*.9))); nvgStrokeWidth(ctx,math.max(1.4,r*.07)); nvgStroke(ctx); nvgRestore(ctx)
end
function M.Cluster(ctx,cx,cy,r,t,seed,a1,a2,rgb,rgb2,alpha) local r1=r*.62; local r2=r*.42; local rot=t*(.28+(seed%5)*.04); M.DrawGear(ctx,cx+math.cos(a1)*(r+r1*.8),cy+math.sin(a1)*(r+r1*.8),r1,8,-rot,rgb2,alpha*.8); M.DrawGear(ctx,cx+math.cos(a2)*(r+r2*.8),cy+math.sin(a2)*(r+r2*.8),r2,9,-rot,rgb2,alpha*.7); M.DrawGear(ctx,cx,cy,r,12+(seed%3)*2,rot,rgb,alpha) end
function M.Corners(ctx,w,t,x,y) M.Cluster(ctx,0,960,17,t,1,math.pi*1.6,math.pi*1.9,x,y,60); M.Cluster(ctx,w,960,20,t,2,math.pi*1.4,math.pi*1.1,y,x,58); M.Cluster(ctx,0,0,16,t,3,.1*math.pi,.4*math.pi,y,x,56); M.Cluster(ctx,w,0,19,t,4,.9*math.pi,.6*math.pi,x,y,62) end
function M.EdgePair(ctx,w,t,x,y) M.Cluster(ctx,w*.5,0,13,t,8,.35*math.pi,.65*math.pi,y,x,54); M.Cluster(ctx,w*.5,960,14,t,9,1.35*math.pi,1.65*math.pi,x,y,56) end
function M.BattleCorners(ctx,w,t,x,y) M.Cluster(ctx,0,960,17,t,10,1.6*math.pi,1.9*math.pi,x,y,58); M.Cluster(ctx,w,960,20,t,11,1.4*math.pi,1.1*math.pi,y,x,56) end
function M.TopBandPair(ctx,w,t,x,y) M.Cluster(ctx,0,140,14,t,14,.1*math.pi,.4*math.pi,x,y,52); M.Cluster(ctx,w,140,15,t,15,.9*math.pi,.6*math.pi,y,x,50) end
function M.HudSides(ctx,w,t,x,y) M.Cluster(ctx,0,330,18,t,16,.15*math.pi,-.15*math.pi,x,y,72); M.Cluster(ctx,w,640,20,t,17,.85*math.pi,1.15*math.pi,y,x,68) end
function M.MenuCenterBottom(ctx,w,t,x,y) M.Cluster(ctx,w*.25,960,18,t,12,1.35*math.pi,1.65*math.pi,x,y,96); M.Cluster(ctx,w*.75,960,20,t,13,1.35*math.pi,1.65*math.pi,y,x,92) end
function M.MenuCorners(ctx,w,t,x,y) M.Cluster(ctx,0,960,17,t,5,1.6*math.pi,1.9*math.pi,x,y,60); M.Cluster(ctx,w,960,20,t,6,1.4*math.pi,1.1*math.pi,y,x,58); M.Cluster(ctx,w,0,18,t,7,.9*math.pi,.6*math.pi,x,y,62) end
return M
