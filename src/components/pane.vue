<template>
  <div :class="$style.pane">
    <router-link to="/" :class="$style.closeButton" v-if="showClose">Close</router-link>
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
    hide-text()
    height 12px + (8px * 2)
    padding 8px
    position absolute
    right 24px
    top 24px
    width 12px + (8px * 2)
    outline 1px solid orange  // XXX
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
