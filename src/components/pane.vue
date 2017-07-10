<template>
  <div :class="$style.pane">
    <router-link to="/" :class="$style.closeButton" v-if="showClose">
      <svg><use href="/icons.svg#x" /></svg>
    </router-link>
    <div style="width: 56px; height: 56px; outline: 1px solid orange;">MARK</div>
    <div style="outline: 1px solid orange;">{{ title }}</div>
    <slot></slot>
  </div>
</template>

<style lang="stylus" module>
  @require '../util.styl'

  .pane
    @extend $pane
    padding-bottom 48px
    padding-top 48px
    position relative

  .close-button
    size = 12px
    padding = 8px
    height size + (padding * 2)
    padding padding
    position absolute
    right 16px
    top 16px
    width size + (padding * 2)
    svg
      height size
      stroke #000
      width size
    &:hover svg
      stroke lh-teal
</style>

<script>
  export default {
    props: {
      showClose: {
        default: true,
        type: Boolean,
      },
      title: {
        required: true,
        type: String,
      },
    },
  };
</script>
