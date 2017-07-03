<template>
  <div>
    <a v-if="pinboardError" :class="$style.error" @click="clearPinboardError">
      Pinboard error: {{ pinboardError }}
    </a>
    <router-view></router-view>
  </div>
</template>

<style lang="stylus" module>
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

  .error
    color lh-salmon
    display block
    font-family Georgia, serif
    font-size 14px
    font-style italic
    margin-bottom 8px
</style>

<script>
  import {mapState} from 'vuex';

  export default {
    computed: mapState(['pinboardError']),

    methods: {
      clearPinboardError() {
        this.$store.commit('clearPinboardError');
      },
    },
  };
</script>
