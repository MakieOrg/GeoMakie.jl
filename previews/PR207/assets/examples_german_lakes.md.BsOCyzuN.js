import{_ as a,c as e,o as s,a6 as n}from"./chunks/framework.CPpXS4ta.js";const u=JSON.parse('{"title":"German lakes","description":"","frontmatter":{},"headers":[],"relativePath":"examples/german_lakes.md","filePath":"examples/german_lakes.md","lastUpdated":null}'),t={name:"examples/german_lakes.md"},l=n(`<h1 id="German-lakes" tabindex="-1">German lakes <a class="header-anchor" href="#German-lakes" aria-label="Permalink to &quot;German lakes {#German-lakes}&quot;">​</a></h1><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span>using GeoMakie, CairoMakie</span></span>
<span class="line"><span>using GeoJSON, Downloads</span></span>
<span class="line"><span>CairoMakie.activate!(px_per_unit = 4) # hide</span></span>
<span class="line"><span></span></span>
<span class="line"><span>geoger = GeoJSON.read(read(Downloads.download(&quot;https://raw.githubusercontent.com/isellsoap/deutschlandGeoJSON/main/2_bundeslaender/4_niedrig.geo.json&quot;), String))</span></span>
<span class="line"><span>lakes = GeoJSON.read(read(Downloads.download(&quot;https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_lakes_europe.geojson&quot;), String))</span></span>
<span class="line"><span></span></span>
<span class="line"><span>fig = Figure()</span></span>
<span class="line"><span>ga = GeoAxis(fig[1, 1]; dest = &quot;+proj=merc&quot;, limits=((6, 15), (47, 55)))</span></span>
<span class="line"><span></span></span>
<span class="line"><span>poly!(ga, geoger; strokewidth = 0.7, color=:gold, rasterize = 5)</span></span>
<span class="line"><span>poly!(ga, lakes; strokewidth = 0.7, color=:blue, rasterize = 5,  xautolimits=false, yautolimits=false)</span></span>
<span class="line"><span>fig</span></span></code></pre></div><hr><p><em>This page was generated using <a href="https://github.com/fredrikekre/Literate.jl" target="_blank" rel="noreferrer">Literate.jl</a>.</em></p>`,4),p=[l];function o(r,i,c,d,m,_){return s(),e("div",null,p)}const h=a(t,[["render",o]]);export{u as __pageData,h as default};
