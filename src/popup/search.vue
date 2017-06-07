<template>
  <div>
    <div :class="$style.top">
      <input type="text" :class="$style.filter"
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
  .top
    display flex

  .filter
    border 1px solid #d3d3d3
    border-radius 4px
    box-shadow inset 0 0 4px rgba(#000, 20%)
    color #4a4a4a
    flex 1
    font bold 18px helvetica neue, sans-serif
    line-height 22px
    padding ((40px - @line-height - 2px) / 2) 15px
    &:focus
      outline none
    &::placeholder
      color #d3d3d3

  .button
    margin-left 8px
    border-radius 4px
    height 40px
    width 40px

  .button-add
    @extend .button
    background #00a2c2

  .button-settings
    @extend .button
    background #4a4a4a

  .list
    list-style none
    margin-bottom 0
    margin-top 8px
    padding 0
    > li:not(:first-child)
      margin-top 2px

  .bookmark
    background #f3f3f3
    border 1px solid transparent
    border-radius 4px
    cursor pointer
    display flex
    padding 7px

  .bookmark.selected
    background #fff
    border-color #f3f3f3

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

  .ellipsis
    overflow hidden
    text-overflow ellipsis
    white-space nowrap

  .title
    @extend .ellipsis
    font-weight bold

  .meta
    color #939393
    display flex
    font-size 11px
    line-height 14px
    :first-child
      @extend .ellipsis
      flex 1
      margin-right 8px
</style>

<script>
  import {mapState} from 'vuex';
  import moment from 'moment';
  import {openUrl} from '@/browser';

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
        handler && handler();
      },

      handleSearchInput(ev) {
        if (this.filterString != ev.target.value) {
          this.selectedIndex = 0
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
        console.count('setSelectedIndex');
        this.selectedIndex = i;
      },
    },
  };
</script>
