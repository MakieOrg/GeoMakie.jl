# Nonlinear transformations


## What are they?

Nonlinear transformations take many forms.  Some are simply "projections" like perspective or orthographic, which are linear in some dimension (representable by a matrix).  Then you have things like log-scale axes, geographic projections, and esoteric physics stuff (like the space near a black hole).

When dealing with nonlinear transformations, it's useful to define our terminology.  _Spaces_ are coordinate spaces, and we consider two relevant ones:
- **Data** space is the space before transformation, also called the **input** space.
- **Transformed** space is the space after transformation is applied.  This can be transformed directly to pixel space by an affine, linear transform.

I can categorize all nonlinear transforms into three types:

### Affine

Any affine transform is not actually nonlinear, but a simple combination of translation, scale and rotation.  They are explained quite well in [this StackOverflow question](https://gamedev.stackexchange.com/questions/72044/why-do-we-use-4x4-matrices-to-transform-things-in-3d).

We don't really consider affine transforms nonlinear here, since they are more or less linear.  But these are the transformations which you generate when you call `translate!`, `rotate!`, or `scale!`.  In these transformations, a straight line is still straight.

### Nonlinear but separable

Here, I mean separable in the sense that systems of ODEs can be separable.  Specifically, _nonlinear and separable_ transforms have the property that each coordinate is independent of all others.  This means that the `x`-coordinate in transformed space depends only on the `x`-coordinate in input space, and so on and so forth for the y and z coordinates.

##### Examples


### Nonlinear and inseparable

Geographic projections are prime examples of this.  The `x`-coordinate in transformed space depends on the input `x` and `y` coordinates, as does the the `y`-coordinate in transformed space.

##### Examples

###### Geographic plots

###### The space near a black hole

## Special situations

## Input v/s transformed bounding boxes

## Coordinate singularities
