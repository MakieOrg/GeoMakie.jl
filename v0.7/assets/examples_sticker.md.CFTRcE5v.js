import{_ as s,c as a,o as p,aA as e}from"./chunks/framework.CYqo74bG.js";const h=JSON.parse('{"title":"","description":"","frontmatter":{},"headers":[],"relativePath":"examples/sticker.md","filePath":"examples/sticker.md","lastUpdated":null}'),l={name:"examples/sticker.md"};function i(t,n,o,r,c,d){return p(),a("div",null,[...n[0]||(n[0]=[e(`<p>We make a sticker by finding the cropping polygon of the interrupted Goode homolosine.</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GeoMakie, CairoMakie</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">import</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GeoInterface </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">as</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GI, GeometryOps </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">as</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GO, GeoFormatTypes </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">as</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GFT</span></span></code></pre></div><p>Obtain boundary points</p><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>n = 31</span></span>
<span class="line"><span>minlon = -180</span></span>
<span class="line"><span>maxlon = 180</span></span>
<span class="line"><span>epsilon = 1e-10</span></span>
<span class="line"><span>central_longitude = 0</span></span>
<span class="line"><span>top_interrupted_lons = (-40.0,)</span></span>
<span class="line"><span>bottom_interrupted_lons = (80.0, -20.0, -100.0)</span></span>
<span class="line"><span># if emphasis == &quot;ocean&quot;:</span></span>
<span class="line"><span>    # top_interrupted_lons = (-90.0, 60.0)</span></span>
<span class="line"><span>    # bottom_interrupted_lons = (90.0, -60.0)</span></span>
<span class="line"><span># end</span></span>
<span class="line"><span>lons = zeros((2 + 2 * (length(top_interrupted_lons) + length(bottom_interrupted_lons))) * n + 1)</span></span>
<span class="line"><span>lats = zeros((2 + 2 * (length(top_interrupted_lons) + length(bottom_interrupted_lons))) * n + 1)</span></span>
<span class="line"><span>stop = 1</span></span>
<span class="line"><span></span></span>
<span class="line"><span># Left boundary</span></span>
<span class="line"><span>lons[stop:stop + n-1] .= minlon</span></span>
<span class="line"><span>lats[stop:stop + n-1] .= LinRange(-90, 90, n)</span></span>
<span class="line"><span>stop += n</span></span>
<span class="line"><span></span></span>
<span class="line"><span># Top boundary</span></span>
<span class="line"><span>for lon in top_interrupted_lons</span></span>
<span class="line"><span>    lons[stop:stop + n-1] .= lon - epsilon + central_longitude</span></span>
<span class="line"><span>    lats[stop:stop + n-1] .= LinRange(90, 0, n)</span></span>
<span class="line"><span>    stop += n</span></span>
<span class="line"><span>    lons[stop:stop + n-1] .= lon + epsilon + central_longitude</span></span>
<span class="line"><span>    lats[stop:stop + n-1] .= LinRange(0, 90, n)</span></span>
<span class="line"><span>    stop += n</span></span>
<span class="line"><span>end</span></span>
<span class="line"><span></span></span>
<span class="line"><span># Right boundary</span></span>
<span class="line"><span>lons[stop:stop + n-1] .= maxlon</span></span>
<span class="line"><span>lats[stop:stop + n-1] .= LinRange(90, -90, n)</span></span>
<span class="line"><span>stop += n</span></span>
<span class="line"><span></span></span>
<span class="line"><span># Bottom boundary</span></span>
<span class="line"><span>for lon in bottom_interrupted_lons</span></span>
<span class="line"><span>    lons[stop:stop + n-1] .= lon + epsilon + central_longitude</span></span>
<span class="line"><span>    lats[stop:stop + n-1] .= LinRange(-90, 0, n)</span></span>
<span class="line"><span>    stop += n</span></span>
<span class="line"><span>    lons[stop:stop + n-1] .= lon - epsilon + central_longitude</span></span>
<span class="line"><span>    lats[stop:stop + n-1] .= LinRange(0, -90, n)</span></span>
<span class="line"><span>    stop += n</span></span>
<span class="line"><span>end</span></span>
<span class="line"><span></span></span>
<span class="line"><span># Close loop</span></span>
<span class="line"><span>lons[end] = minlon</span></span>
<span class="line"><span>lats[end] = -90</span></span>
<span class="line"><span></span></span>
<span class="line"><span>ring = GI.LinearRing(tuple.(lons, lats))</span></span>
<span class="line"><span>projected_ring = GO.reproject(ring, GFT.EPSG(4326), GFT.ProjString(&quot;+proj=igh +type=crs&quot;))</span></span>
<span class="line"><span>ext = GI.extent(projected_ring)</span></span>
<span class="line"><span>ext_ring = GI.LinearRing([(ext.X[1], ext.Y[1]), (ext.X[1], ext.Y[2]), (ext.X[2], ext.Y[2]), (ext.X[2], ext.Y[1]), (ext.X[1], ext.Y[1]), ])</span></span>
<span class="line"><span>cropping_poly = GI.Polygon([ext_ring, projected_ring])</span></span></code></pre></div><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span>fig = Figure()</span></span>
<span class="line"><span>ax = GeoAxis(fig[1, 1]; dest = &quot;+proj=igh&quot;)</span></span>
<span class="line"><span>background_plot = meshimage!(ax, -180..180, -90..90, rotr90(GeoMakie.earth()); npoints = 500)</span></span>
<span class="line"><span>logo_plot = meshimage!(ax, -180..180, -90..90, rotr90(Makie.logo()); npoints = 500)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>hidedecorations!(ax)</span></span>
<span class="line"><span>xgrid_plot = lines!(ax.scene, ax.elements[:xgrid][1]; color = ax.xgridcolor, alpha = 0.5)</span></span>
<span class="line"><span>ygrid_plot = lines!(ax.scene, ax.elements[:ygrid][1]; color = ax.ygridcolor, alpha = 0.5)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>cropping_plot = poly!(ax.scene, cropping_poly; color = :white, strokecolor = ax.xgridcolor)</span></span>
<span class="line"><span>fig</span></span></code></pre></div><hr><p><em>This page was generated using <a href="https://github.com/fredrikekre/Literate.jl" target="_blank" rel="noreferrer">Literate.jl</a>.</em></p>`,7)])])}const _=s(l,[["render",i]]);export{h as __pageData,_ as default};
