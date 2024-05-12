import{_ as a,c as e,o as s,a6 as n}from"./chunks/framework.CPpXS4ta.js";const g=JSON.parse('{"title":"GMT vector example","description":"","frontmatter":{},"headers":[],"relativePath":"examples/antioquia.md","filePath":"examples/antioquia.md","lastUpdated":null}'),t={name:"examples/antioquia.md"},p=n(`<h1 id="GMT-vector-example" tabindex="-1">GMT vector example <a class="header-anchor" href="#GMT-vector-example" aria-label="Permalink to &quot;GMT vector example {#GMT-vector-example}&quot;">​</a></h1><p>This example was translated from the <a href="https://www.generic-mapping-tools.org/GMTjl_doc/tutorials/vector_shp/vector_shp/" target="_blank" rel="noreferrer">equivalent GMT.jl example</a>.</p><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span>using GMT # for data</span></span>
<span class="line"><span>using GeoMakie, Polylabel, Shapefile</span></span>
<span class="line"><span></span></span>
<span class="line"><span>import ZipFile, Shapefile</span></span>
<span class="line"><span></span></span>
<span class="line"><span>table = Shapefile.Table(joinpath(GMT.TESTSDIR, &quot;COL_adm2.shp.zip&quot;))</span></span>
<span class="line"><span></span></span>
<span class="line"><span>antioquia_geoms = filter(:NAME_1 =&gt; ==(&quot;Antioquia&quot;), table)</span></span>
<span class="line"><span></span></span>
<span class="line"><span>f, a, p = poly(antioquia_geoms.geometry; axis = (; type = GeoAxis))</span></span>
<span class="line"><span>tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))</span></span>
<span class="line"><span>tp.fontsize = 5</span></span>
<span class="line"><span>f</span></span></code></pre></div><p>Now that the polygons are labelled, we can also color them:</p><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span>f, a, p = poly(antioquia_geoms.geometry; color = antioquia_geoms.ID_2 .|&gt; identity, colormap = :bamako, axis = (; type = GeoAxis))</span></span>
<span class="line"><span>tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))</span></span>
<span class="line"><span>tp.fontsize = 5</span></span>
<span class="line"><span>a.title = &quot;Another Map of Antioquia&quot;</span></span>
<span class="line"><span>cb = Colorbar(f[1, 2], p)</span></span>
<span class="line"><span>f</span></span></code></pre></div><p>Note that this is not projected - the <code>proj=:guess</code> projection is not implemented in GeoMakie! However, we can project to an orthographic projection centered at the centroid of the geometry, using GeometryOps.jl to calculate the centroid.</p><div class="language-@example vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">@example</span><pre class="shiki shiki-themes github-light github-dark vp-code"><code><span class="line"><span>import GeometryOps as GO</span></span>
<span class="line"><span>cx, cy = GO.centroid(antioquia_geoms)</span></span>
<span class="line"><span>a.dest = &quot;+proj=ortho +lon_0=$cx +lat_0=$cy&quot;</span></span>
<span class="line"><span>f</span></span></code></pre></div><p>That looks a lot more like what the GMT example does!</p><hr><p><em>This page was generated using <a href="https://github.com/fredrikekre/Literate.jl" target="_blank" rel="noreferrer">Literate.jl</a>.</em></p>`,10),o=[p];function l(i,c,r,h,m,d){return s(),e("div",null,o)}const _=a(t,[["render",l]]);export{g as __pageData,_ as default};
