<template>
  <!-- TODO: vertical margin everywhere -->
  <pane :class="$style.add" :title="title">
    <div v-if="existingBookmark">
      <!-- TODO style -->
      You bookmarked this page {{ existingBookmarkAge }}.
    </div>
    <input :class="$style.title" placeholder="Title" :value="bookmark.description">
    <input :class="$style.url" placeholder="URL" tabindex="-1" :value="bookmark.href">
    <transition-group tag="ul" :class="$style.tags"
      :name="animateTags && !animateTagPause ? 'tag' : null">
      <li :class="$style.tag" v-for="tag in bookmark.tags" :key="tag"
        @click="removeTag(tag)">{{ tag }}</li>
      <!-- TODO: add close X -->
      <!-- TODO: tag autocomplete -->
      <input :class="$style.tagInput" :placeholder="addTagPlaceholder"
        key=" " :size="tagInputSize"
        :value="newTag"
        @input="handleTagInput"
        @keydown="handleTagKeyDown">
    </transition-group>
    <transition-group tag="ul" :class="$style.suggestedTags"
      :name="animateTags ? 'tag' : null">
      <li v-for="tag in unusedSuggestedTags" :class="$style.tag"
        @click="addTag(tag)" :key="tag">
        {{ tag }}
      </li>
    </transition-group>

    <!-- TODO: style -->
    <label><input type="checkbox"> This link is private</label>

    <a :class="$style.button">Save to Pinboard</a>
  </pane>
</template>

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

<style lang="stylus" module>
  @require '../util';

  .add
    align-items center
    display flex
    flex-direction column
    padding 32px

  .title, .url, .tags
    @extend $input
    width 100%

  .url, .tags
    light-text()
    line-height 22px

  .url
    margin 8px 0
    transition all 150ms ease-in-out
    transform translateY(0)
    &:not(:focus)
      background-color transparent
      border-color transparent
      box-shadow none
      transform translateY(-8px)
      &:hover
        color lh-teal

  tag-bottom-margin = 4px
  tag-height = 21px
  $tags
    light-text()
    align-items center
    display flex
    flex-wrap wrap
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
    @extend $tags
    list-style none
    margin 0
    min-height 40px
    padding-bottom 8px - tag-bottom-margin
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
    @extend $tags
    plain-list()
    margin-top 8px
    .tag
      background rgba(#fff, .5)
      display inline-block

  .button
    @extend $button
</style>

<script>
  import {getSelectedTab} from '@/browser';
  import moment from 'moment';
  import {getSuggestedTags} from '@/pinboard';
  import Pane from '@/components/pane';

  export default {
    components: {Pane},

    data() {
      return {
        addTagPlaceholder: 'Add tags',
        animateTags: false,
        animateTagPause: false,
        bookmark: {
          description: null,
          href: null,
          tags: [],
        },
        newTag: '',
        suggestedTags: [],
      };
    },

    computed: {
      existingBookmark() {
        return this.$store.state.bookmarks.find(b => b.href === this.bookmark.href);
      },

      existingBookmarkAge() {
        if (!this.existingBookmark) return null;
        return moment(this.existingBookmark.time).fromNow();
      },

      tagInputSize() {
        return Math.max(1, this.newTag.length, this.addTagPlaceholder.length);
      },

      title() {
        return `${this.existingBookmark ? 'Edit' : 'Add'} Link`;
      },

      unusedSuggestedTags() {
        return this.suggestedTags.filter(t => !this.bookmark.tags.includes(t));
      },
    },

    methods: {
      addTag(tag) {
        tag = tag.trim();
        if (!this.bookmark.tags.includes(tag)) {
          this.bookmark.tags.push(tag);
        }
      },

      handleTagInput(ev) {
        this.addTagPlaceholder = '';
        this.newTag = ev.target.value || '';
      },

      handleTagKeyDown(ev) {
        const addTag = () => {
          ev.preventDefault();
          this.addTag(this.newTag);
          this.newTag = '';
        };
        const handler = {
          Backspace: () => {
            if (this.newTag === '') {
              ev.preventDefault();
              this.animateTagPause = true;
              const newTag = this.bookmark.tags.pop() || '';
              // Prevent flash when deleting into an existing tag by waiting at
              // least one render cycle.
              setTimeout(() => {
                this.animateTagPause = false;
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

      removeTag(tag) {
        this.bookmark.tags = this.bookmark.tags.filter(t => t !== tag);
      },
    },

    mounted() {
      // XXX how to handle changing url on an existing link?
      getSelectedTab().then(t => {
        this.bookmark.href = t.url;
        this.bookmark.description = t.title;
        getSuggestedTags(t.url).then(tags => {
          this.suggestedTags = tags;
          requestAnimationFrame(() => this.animateTags = true);
        });
        if (this.existingBookmark) {  // depends on this.bookmark.href
          this.bookmark.description = this.existingBookmark.description;
          this.bookmark.tags = this.bookmark.tags.concat(this.existingBookmark.tags);
        }
      });
    },
  };
</script>
