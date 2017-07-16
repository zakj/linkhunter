<template>
  <div>
    <transition-group tag="ul" :class="$style.tags"
      :name="loaded && !pauseAddAnimation ? 'tag' : null">
      <li :class="$style.tag" v-for="tag in tags" :key="tag"
        @click="$emit('remove', tag)">
        {{ tag }}
        <svg><use href="/icons.svg#x" /></svg>
      </li>
      <div :class="$style.autocomplete" key="autocomplete">
        <div :class="$style.tagOutput">
          {{ placeholder }}
          {{ newTag }}<span :class="$style.suggestion">{{ suggestionSuffix }}</span>
        </div>
        <input :class="$style.tagInput" ref="tagInput" :value="newTag"
          @input="handleTagInput" @keydown="handleTagKeyDown" @blur="addTag">
      </div>
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
      svg
        height 7px
        left 2px
        opacity .5
        position relative
        stroke #fff
        width 7px
      &:hover svg
        opacity 1

  .autocomplete
    flex 1
    line-height tag-height
    margin-bottom tag-bottom-margin
    position relative

  .tag-output
    color lh-grey-9
    height tag-height
    pointer-events none
    white-space nowrap

  .tag-input
    background transparent
    border none
    font inherit
    left 0
    padding 0
    position absolute
    top 0
    width 100%
    -webkit-text-fill-color transparent  // maintain cursor, hide text
    &:focus
      outline none

  .suggestion
    opacity .3

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
  import _ from 'lodash/fp';
  import {mapGetters} from 'vuex';

  export default {
    data() {
      return {
        newTag: '',
        pauseAddAnimation: false,
        placeholder: 'Add tags',
      };
    },

    computed: {
      suggestion() {
        if (this.newTag) {
          const unusedCommonTags = _.difference(this.mostCommonTags, this.tags);
          const suggestion = _.find(_.startswith(this.newTag), unusedCommonTags);
          return suggestion || '';
        }
        return '';
      },

      suggestionSuffix() {
        return this.suggestion.substring(this.newTag.length);
      },

      unusedSuggestedTags() {
        return this.suggestedTags.filter(t => !this.tags.includes(t));
      },

      ...mapGetters(['mostCommonTags']),
    },

    methods: {
      addTag() {
        this.$emit('add', this.newTag);
        this.newTag = '';
      },

      handleTagInput(ev) {
        this.placeholder = '';
        this.newTag = ev.target.value || '';
      },

      handleTagKeyDown(ev) {
        const addTag = () => {
          ev.preventDefault();
          this.addTag();
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
          Tab: () => {
            if (this.suggestion) this.newTag = this.suggestion;
            addTag();
          },
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
