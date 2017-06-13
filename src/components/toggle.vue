<template>
  <div :class="{[$style.toggle]: true, [$style.toggleOn]: on}"
    @click="$emit('toggle')">
    <div :class="$style.toggleButton">
      <svg xmlns="http://www.w3.org/2000/svg" width="16px" height="16px">
        <g :class="$style.toggleIcon" fill="none" stroke-width="2">
          <path ref="togglePath" :d="iconPath" />
        </g>
      </svg>
    </div>
  </div>
</template>

<style lang="stylus" module>
  @require '../util.styl'

  .toggle
    background lh-grey-4
    border-radius 24px
    cursor pointer
    height 40px
    margin 12px auto 24px
    padding 1px
    transition background 150ms ease-in-out
    user-select none
    width 72px

  .toggle-button
    align-items center
    background #fff
    border-radius 38px
    display flex
    height 38px
    justify-content center
    transition transform 150ms ease-in-out
    width 38px

  .toggle-icon
    stroke lh-grey-4
    transition stroke 150ms ease-in-out

  .toggle.toggle-on
    background lh-teal
    .toggle-button
      transform translateX(32px)
    .toggle-icon
      stroke lh-teal
      stroke-endcap round
      stroke-linecap round
</style>

<script>
  import anime from 'animejs';

  const ICON_PATHS = {
    [true]: 'M3,8.5 L6.5,12 M6.5,12 L14,4',
    [false]: 'M3,3 L13,13 M3,13 L13,3',
  };

  export default {
    props: {
      on: Boolean,
    },

    data() {
      return {
        tweeningIconPath: null,
      };
    },

    computed: {
      iconPath() {
        return this.tweeningIconPath || ICON_PATHS[this.on];
      },
    },

    watch: {
      on(newValue, oldValue) {
        this.tweeningIconPath = ICON_PATHS[oldValue];
        anime({
          targets: this.$data,
          tweeningIconPath: ICON_PATHS[newValue],
          easing: 'easeOutQuad',
          duration: 200,
        });
      },
    },
  };
</script>
