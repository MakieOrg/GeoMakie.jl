```@meta
Draft=false
```

```@raw html
<script setup lang="ts">
import Gallery from "./components/Gallery.vue";

const basic = [
{
    "href": 'examples/axis_config',
    "src": 'examples/covers/axis_config.png',
    "caption": 'Axis configuration',
    "desc": 'Ways to configure and theme GeoAxis',
},
{
    "href": 'examples/basic',
    "src": 'examples/covers/basic.png',
    "caption": 'Basic GeoMakie usage',
    "desc": 'Basic GeoMakie usage',
},
{
    "href": 'examples/contourf',
    "src": 'examples/covers/contourf.png',
    "caption": 'Filled contours',
    "desc": '',
},
]


const advanced = [
{
    "href": 'examples/tissot',
    "src": 'examples/covers/tissot.png',
    "caption": 'Tissot\'s indicatrices',
    "desc": 'Visualizing distortion in projections',
},
{
    "href": 'examples/world_population',
    "src": 'examples/covers/world_population.png',
    "caption": 'World Population',
    "desc": 'A plot of world population',
},
]

</script>
```

# Example gallery {#Example-gallery}

This page is a gallery of various examples.

## Basic examples

```@raw html
<Gallery :images="basic" />
```

## Advanced functionality

```@raw html
<Gallery :images="advanced" />
```


```@eval
# using Main.Gallery
# mdify([
#     Card(
#         path = "axis_config",
#         desc = "Ways to configure and theme GeoAxis",
#         caption = "Axis configuration"
#     ),
#     Card(
#         path = "basic",
#         desc = "Basic GeoMakie usage",
#         caption = "Basic GeoMakie usage"
#     ),
#     Card(
#         path = "contourf",
#         caption = "Filled contours"
#     ),
# ]; name = "basic")
nothing
```

## Advanced functionality

```@eval
# using Main.Gallery
# mdify([
#     Card(
#         path = "tissot",
#         desc = "Visualizing distortion in projections",
#         caption = "Tissot's indicatrices"
#     ),
#     Card(
#         path = "world_population",
#         desc = "A plot of world population",
#         caption = "World Population"
#     ),
# ]; name = "advanced")
nothing
```

