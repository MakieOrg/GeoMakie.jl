import{_ as s,c as a,o as n,a6 as e}from"./chunks/framework.CPpXS4ta.js";const g=JSON.parse('{"title":"Field and countries","description":"","frontmatter":{},"headers":[],"relativePath":"examples/field_and_countries.md","filePath":"examples/field_and_countries.md","lastUpdated":null}'),i={name:"examples/field_and_countries.md"},p=e(`<h1 id="Field-and-countries" tabindex="-1">Field and countries <a class="header-anchor" href="#Field-and-countries" aria-label="Permalink to &quot;Field and countries {#Field-and-countries}&quot;">​</a></h1><p>This example was taken from Lazaro Alonso&#39;s BeautifulMakie.jl repository. It has some really good stuff - check it out!</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Makie, CairoMakie, GeoMakie</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">import</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Downloads</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GeoMakie</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">GeoJSON</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GeometryBasics</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> GeoMakie</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">GeoInterface</span></span></code></pre></div><p><a href="https://datahub.io/core/geo-countries#curl" target="_blank" rel="noreferrer">https://datahub.io/core/geo-countries#curl</a> # download data from here</p><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span>path = GeoMakie.assetpath(&quot;vector&quot;, &quot;countries.geo.json&quot;)</span></span>
<span class="line"><span>json_str = read(path, String)</span></span>
<span class="line"><span>worldCountries = GeoJSON.read(json_str)</span></span>
<span class="line"><span>n = length(worldCountries)</span></span>
<span class="line"><span>lons = -180:180</span></span>
<span class="line"><span>lats = -90:90</span></span>
<span class="line"><span>field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]</span></span>
<span class="line"><span></span></span>
<span class="line"><span>fig = Figure(size = (1200,800), fontsize = 22)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>ax = GeoAxis(</span></span>
<span class="line"><span>    fig[1,1];</span></span>
<span class="line"><span>    dest=&quot;+proj=wintri&quot;,</span></span>
<span class="line"><span>    title = &quot;World Countries&quot;,</span></span>
<span class="line"><span>    tellheight = true,</span></span>
<span class="line"><span>)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>hm1 = surface!(ax, lons, lats, field; shading = NoShading)</span></span>
<span class="line"><span>translate!(hm1, 0, 0, -10)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>hm2 = poly!(</span></span>
<span class="line"><span>    ax, worldCountries;</span></span>
<span class="line"><span>    color= 1:n,</span></span>
<span class="line"><span>    colormap = Reverse(:plasma),</span></span>
<span class="line"><span>    strokecolor = :black,</span></span>
<span class="line"><span>    strokewidth = 0.25</span></span>
<span class="line"><span>)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>cb = Colorbar(fig[1,2]; colorrange = (1, n), colormap = Reverse(:plasma), label = &quot;variable, color code&quot;, height = Relative(0.65))</span></span>
<span class="line"><span></span></span>
<span class="line"><span>fig</span></span></code></pre></div><hr><p><em>This page was generated using <a href="https://github.com/fredrikekre/Literate.jl" target="_blank" rel="noreferrer">Literate.jl</a>.</em></p>`,7),l=[p];function t(o,r,c,h,d,k){return n(),a("div",null,l)}const _=s(i,[["render",t]]);export{g as __pageData,_ as default};
