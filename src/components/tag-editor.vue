<template>
  <div>
    <transition-group tag="ul" :class="$style.tags"
      :name="loaded && !pauseAddAnimation ? 'tag' : null">
      <li :class="$style.tag" v-for="tag in tags" :key="tag"
        @click="$emit('remove', tag)">{{ tag }}</li>
      <!-- TODO: add close X -->
      <!-- TODO: tag autocomplete -->
      <input :class="$style.tagInput" :placeholder="placeholder"
        key=" " :size="inputSize"
        :value="newTag"
        @input="handleTagInput"
        @keydown="handleTagKeyDown">
    </transition-group>
    <transition-group tag="ul" :class="$style.suggestedTags"
      :name="loaded ? 'tag' : null">
      <li v-for="tag in unusedSuggestedTags" :class="$style.tag"
        @click="$emit('add', tag)" :key="tag">{{ tag }}</li>
    </transition-group>
  </div>
</template>

<style lang="stylus" module>
  @require '../util';

  tag-bottom-margin = 4px
  tag-height = 21px

  $tags-base
    light-text()
    align-items center
    display flex
    flex-wrap wrap
    line-height 22px
    width 100%
    .tag
      border-radius 16px
      cursor pointer
      line-height tag-height
      margin-bottom tag-bottom-margin
      margin-right 4px
      padding 0 10px
      user-select none
      &:hover  // XXX needs design, copied from button. factor into shine mixin?
        background-image linear-gradient(170deg, rgba(#fff, 50%), rgba(#fff, 0) 80%)

  .tags
    @extend $input
    @extend $tags-base
    list-style none
    margin 0
    min-height 40px
    padding-bottom 8px - tag-bottom-margin
    width 100%
    .tag
      background lh-grey-4
      color #fff
      -webkit-font-smoothing antialiased

  .tag-input
    border none
    line-height tag-height
    margin-bottom tag-bottom-margin
    padding 0
    flex 1
    &:focus
      outline none

  .suggested-tags
    @extend $tags-base
    plain-list()
    margin-top 8px
    .tag
      background rgba(#fff, .5)
      display inline-block
</style>

<style lang="stylus">
  @require '../util';

  .tag-enter-active, .tag-leave-active
    transition all 250ms ease-out-back
  .tag-leave-active
    transition-timing-function ease-out
  .tag-enter, .tag-leave-to
    opacity .3
    transform scale(0)
</style>

<script>
  export default {
    data() {
      return {
        pauseAddAnimation: false,
        placeholder: 'Add tags',
        newTag: '',
      };
    },

    computed: {
      inputSize() {
        return Math.max(1, this.newTag.length, this.placeholder.length);
      },

      unusedSuggestedTags() {
        return this.suggestedTags.filter(t => !this.tags.includes(t));
      },
    },

    methods: {
      handleTagInput(ev) {
        this.placeholder = '';
        this.newTag = ev.target.value || '';
      },

      handleTagKeyDown(ev) {
        const addTag = () => {
          ev.preventDefault();
          this.$emit('add', this.newTag);
          this.newTag = '';
        };
        const handler = {
          Backspace: () => {
            if (this.newTag === '' && this.tags.length > 0) {
              ev.preventDefault();
              this.pauseAddAnimation = true;
              const newTag = this.tags[this.tags.length - 1];
              this.$emit('remove', newTag);
              // Prevent flash when deleting into an existing tag by waiting at
              // least one render cycle.
              setTimeout(() => {
                this.pauseAddAnimation = false;
                this.newTag = newTag;
              }, 16);
            }
          },
          Escape: () => {
            ev.preventDefault();
            this.newTag = '';
          },
          Enter: addTag,
          ' ': addTag,
        }[ev.key];
        if (handler) handler();
      },
    },

    props: {
      loaded: {
        default: true,
        type: Boolean,
      },
      suggestedTags: {
        default: [],
        type: Array,
      },
      tags: {
        required: true,
        type: Array,
      },
    },
  };
</script>
