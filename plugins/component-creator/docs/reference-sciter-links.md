---
description: "Quick-reference links for Sciter.js documentation and related tooling. Read when implementing Sciter components."
---

# Sciter.js — Reference Links

## Reactor (JSX + Components)

| Topic | URL |
| ---- | ---- |
| Overview | https://docs.sciter.com/docs/Reactor/ |
| JSX syntax + shortcuts | https://docs.sciter.com/docs/Reactor/JSX |
| JSX i18n (`@"string"`) | https://docs.sciter.com/docs/Reactor/JSX-i18n |
| Rendering + mounting | https://docs.sciter.com/docs/Reactor/rendering |
| Component class | https://docs.sciter.com/docs/Reactor/component |
| `componentUpdate()` | https://docs.sciter.com/docs/Reactor/component-update |
| Styles + events | https://docs.sciter.com/docs/Reactor/component-styles-events |
| Lists + keys | https://docs.sciter.com/docs/Reactor/lists-and-keys |
| Signals API | https://docs.sciter.com/docs/Reactor/signals |
| Lifecycle methods | https://docs.sciter.com/docs/Reactor/component-lifecycle |
| Top-level API | https://docs.sciter.com/docs/Reactor/reactor-api |
| Reactor vs ReactJS | https://docs.sciter.com/docs/Reactor/reactor-vs-reactjs |

## CSS

| Topic | URL |
| ---- | ---- |
| All properties | https://docs.sciter.com/docs/CSS/properties |
| Selectors | https://docs.sciter.com/docs/CSS/selectors |
| Flows + flexes (`flow:`) | https://docs.sciter.com/docs/CSS/flows-and-flexes |
| Variables + attributes | https://docs.sciter.com/docs/CSS/variables-and-attributes |
| Style sets (`styleset:`) | https://docs.sciter.com/docs/CSS/style-sets |
| `@media`, `@const`, `@mixin` | https://docs.sciter.com/docs/CSS/at-media-const-mixin |
| Behaviors + aspects | https://docs.sciter.com/docs/CSS/behaviors-and-aspects |
| Scrollbars | https://docs.sciter.com/docs/CSS/scrollbars-styling |
| Vector images / `icon()` | https://docs.sciter.com/docs/CSS/vector-images |
| Pseudo-elements | https://docs.sciter.com/docs/CSS/pseudo-elements |
| Sprite `@image-map` | https://docs.sciter.com/docs/CSS/image-map |
| Units (color, dimension) | https://docs.sciter.com/docs/CSS/units |

## DOM

| Topic | URL |
| ---- | ---- |
| Element | https://docs.sciter.com/docs/DOM/Element |
| Element.State | https://docs.sciter.com/docs/DOM/Element.State |
| Element.Style | https://docs.sciter.com/docs/DOM/Element.Style |
| Event | https://docs.sciter.com/docs/DOM/Event |
| Window | https://docs.sciter.com/docs/DOM/Window |
| Behaviors reference | https://docs.sciter.com/docs/behaviors/ |

## JS Runtime

| Topic | URL |
| ---- | ---- |
| JS runtime | https://docs.sciter.com/docs/JS.runtime/ |
| Storage | https://docs.sciter.com/docs/Storage/ |
| Graphics | https://docs.sciter.com/docs/Graphics/ |
| URL schemes | https://docs.sciter.com/docs/URL-sciter-schemes |

## Figma Code Connect

| Topic | URL |
| ---- | ---- |
| No-parser setup | https://developers.figma.com/docs/code-connect/no-parser/ |
| Config file | https://developers.figma.com/docs/code-connect/api/config-file/ |
| React API (reference) | https://developers.figma.com/docs/code-connect/react/ |

## Font Assets

```
# Static TTF — reliable CDN (use instead of github raw which returns HTML redirects)
https://cdn.jsdelivr.net/fontsource/fonts/{font-id}@latest/latin-{weight}-normal.ttf

# Example: Open Sans 500
https://cdn.jsdelivr.net/fontsource/fonts/open-sans@latest/latin-500-normal.ttf
```

## Figma REST API

```
# Component screenshot (PNG, 2x retina, absolute bounds)
GET https://api.figma.com/v1/images/:fileKey?ids=:nodeId&format=png&scale=2&use_absolute_bounds=true

# SVG export
GET https://api.figma.com/v1/images/:fileKey?ids=:nodeId&format=svg
```
