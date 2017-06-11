<template>
  <router-view></router-view>
</template>

<style lang="stylus">
  @require '../util'

  *
    box-sizing border-box

  body
    color #333
    font 13px/18px Helvetica Neue, Helvetica, sans-serif
    margin 7px
    width 400px

  a
    cursor pointer

  .pane
    background #f3f3f3
    border-radius 4px
    padding 10px 15px
    position relative

  .close-button
    @extend $hide-text
    height 12px
    position absolute
    right 24px
    top 24px
    width 12px
    outline 1px solid orange  // XXX
</style>
