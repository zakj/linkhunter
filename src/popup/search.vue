<template>
  <div>
    <div :class="$style.top">
      <input type="text" :class="$style.filter" v-focus="true"
        placeholder="Search" :value="filterString"
        @input="handleSearchInput($event)"
        @keydown="handleKeyDown"
        @blur="refocus">
      <router-link :class="$style.buttonAdd" to="/add">Add</router-link>
      <router-link :class="$style.buttonSettings" to="/settings">Settings</router-link>
    </div>

    <ul :class="$style.list">
      <li v-for="(bookmark, i) in filteredBookmarks">
        <a :class="{[$style.bookmark]: true, [$style.selected]: i === selectedIndex}"
          @click="handleBookmarkClick($event, bookmark.href)"
          @mouseenter="setSelectedIndex(i)">
          <div :class="$style.icon">
            <img :src="iconFor(bookmark.href)" width="16" height="16">
          </div>
          <div :class="$style.text">
            <div :class="$style.title">{{ bookmark.description }}</div>
            <div :class="$style.meta">
              <div>{{ bookmark.href }}</div>
              <div>{{ age(bookmark.time) }}</div>
            </div>
          </div>
        </a>
      </li>
    </ul>
  </div>
</template>

<style lang="stylus" module>
  @require '../util'

  .top
    display flex

  .filter
    border 1px solid lh-grey-d
    border-radius 4px
    box-shadow inset 0 0 4px rgba(#000, 20%)
    color lh-grey-4
    flex 1
    font bold 18px helvetica neue, sans-serif
    line-height 22px
    padding ((40px - @line-height - 2px) / 2) 15px
    &:focus
      outline none
    &::placeholder
      color lh-grey-d

  .button
    @extend $hide-text
    border-radius 4px
    height 40px
    margin-left 8px
    width 40px
    &:hover  // XXX needs design
      background-image linear-gradient(170deg, rgba(#fff, 50%), rgba(#fff, 0) 80%)

  .button-add
    @extend .button
    background lh-teal

  .button-settings
    @extend .button
    background lh-grey-4

  .list
    list-style none
    margin-bottom 0
    margin-top 8px - 2px
    padding 0
    li
      margin-top 2px

  .bookmark
    background lh-grey-f
    border 1px solid transparent
    border-radius 4px
    display flex
    padding 7px

  .bookmark.selected
    background #fff
    border-color lh-grey-f

  .icon
    background rgba(#fff, 50%)
    border-radius 4px
    height 40px
    margin-right 8px
    padding ((@height - 16px) / 2)
    width @height

  .text
    display flex
    flex 1
    flex-direction column
    justify-content center
    min-width 0

  .title
    @extend $ellipsis
    font-weight bold

  .meta
    @extend $light-text
    display flex
    :first-child
      @extend $ellipsis
      flex 1
      margin-right 8px
</style>

<script>
  import {focus} from 'vue-focus';
  import {mapState} from 'vuex';
  import moment from 'moment';
  import {openUrl, sendMessage} from '@/browser';

  // Used for parsing URLs in iconFor.
  const linkEl = document.createElement('a');

  // Words in the query string are separated by whitespace and/or commas. Every
  // word in the query must match in a bookmark's tags or description.
  function filterBookmarks(query, bookmarks) {
    if (!query) return bookmarks;
    const regexps = query.split(/[, ]+/).map(word => new RegExp(word, 'i'));
    return bookmarks.filter(b => {
      const s = [b.tags, b.description].join(' ');
      return regexps.every(re => re.test(s));
    });
  }

  export default {
    data() {
      return {
        filterString: '',
        selectedIndex: 0,
      };
    },

    directives: {focus},

    computed: {
      filteredBookmarks() {
        return filterBookmarks(this.filterString, this.bookmarks);
      },

      ...mapState(['bookmarks']),
    },

    methods: {
      age(time) {
        return moment(time).fromNow();
      },

      handleBookmarkClick(ev, url) {
        openUrl({url, background: ev.metaKey || ev.ctrlKey});
      },

      handleKeyDown(ev) {
        const handler = {
          Escape: () => {
            ev.preventDefault();
            if (this.filterString) {
              this.filterString = '';
            }
            else {
              window.close();
            }
          },
          Enter: () => {
            const url = this.filteredBookmarks[this.selectedIndex].href;
            openUrl({url, background: ev.metaKey || ev.ctrlKey});
          },
          ArrowDown: () => {
            this.selectedIndex = Math.min(
              this.filteredBookmarks.length - 1,
              this.selectedIndex + 1
            );
          },
          ArrowUp: () => {
            this.selectedIndex = Math.max(0, this.selectedIndex - 1);
          },
        }[ev.key];
        if (handler) handler();
      },

      handleSearchInput(ev) {
        if (this.filterString !== ev.target.value) {
          this.selectedIndex = 0;
        }
        this.filterString = ev.target.value;
      },

      iconFor(url) {
        linkEl.href = url;
        return `https://icons.duckduckgo.com/ip2/${linkEl.host}.ico`;
      },

      refocus(ev) {
        requestAnimationFrame(() => ev.target.focus());
      },

      setSelectedIndex(i) {
        this.selectedIndex = i;
      },
    },

    mounted() {
      sendMessage({type: 'updateBookmarks'});
    },
  };
</script>
