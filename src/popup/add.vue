<template>
  <!-- TODO: vertical margin everywhere -->
  <pane :class="$style.add" :title="title">
    <div v-if="existingBookmark">
      <!-- TODO style -->
      You bookmarked this page {{ existingBookmarkAge }}.
    </div>

    <input :class="$style.title" placeholder="Title" :value="bookmark.description"
      @input="bookmark.description = $event.target.value">
    <input :class="$style.url" placeholder="URL" tabindex="-1" :value="bookmark.href"
      @input="bookmark.href = $event.target.value">
    <tag-editor :class="$style.tags"
      :tags="bookmark.tags"
      :suggested-tags="suggestedTags"
      :loaded="loadedSuggestedTags"
      @add="addTag" @remove="removeTag"></tag-editor>

    <!-- TODO: style saveError and saving state -->
    {{ saveError }}

    <!-- TODO: style -->
    <label><input type="checkbox" v-model="bookmark.shared"> This link is private</label>

    <a :class="$style.button" @click="saveBookmark">Save to Pinboard</a>
  </pane>
</template>

<style lang="stylus" module>
  @require '../util';

  .add
    align-items center
    display flex
    flex-direction column
    padding 32px

  .title, .url
    @extend $input
    width 100%

  .url
    light-text()
    line-height 22px
    margin 8px 0
    transform translateY(0)
    transition all 150ms ease-in-out
    &:not(:focus)
      background-color transparent
      border-color transparent
      box-shadow none
      transform translateY(-8px)
      &:hover
        color lh-teal

  .tags
    width 100%

  .button
    @extend $button
</style>

<script>
  import {getSelectedTab} from '@/browser';
  import moment from 'moment';
  import {getSuggestedTags, saveBookmark} from '@/pinboard';
  import Pane from '@/components/pane';
  import TagEditor from '@/components/tag-editor';

  export default {
    components: {Pane, TagEditor},

    data() {
      return {
        bookmark: {
          description: null,
          href: null,
          shared: !this.$store.state.defaultPrivate,
          tags: [],
        },
        loadedSuggestedTags: false,
        saveError: '',
        saving: false,
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

      title() {
        return `${this.existingBookmark ? 'Edit' : 'Add'} Link`;
      },
    },

    methods: {
      addTag(tag) {
        tag = tag.trim();
        if (tag && !this.bookmark.tags.includes(tag)) {
          this.bookmark.tags.push(tag);
        }
      },

      removeTag(tag) {
        this.bookmark.tags = this.bookmark.tags.filter(t => t !== tag);
      },

      saveBookmark() {
        if (this.saving) return;
        this.saving = true;
        saveBookmark(this.bookmark)
          .then(() => this.$router.push('/'))
          .catch(error => {
            this.saving = false;
            this.saveError = error.toString();
          });
      },
    },

    mounted() {
      // XXX how to handle changing url on an existing link?
      // XXX/TODO: set desc/url on model when changing inputs
      getSelectedTab().then(t => {
        this.bookmark.href = t.url;
        this.bookmark.description = t.title;
        getSuggestedTags(t.url).then(tags => {
          this.suggestedTags = tags;
          requestAnimationFrame(() => this.loadedSuggestedTags = true);
        });
        if (this.existingBookmark) {  // depends on this.bookmark.href
          this.bookmark.description = this.existingBookmark.description;
          this.bookmark.tags = this.bookmark.tags.concat(this.existingBookmark.tags);
        }
      });
    },
  };
</script>
