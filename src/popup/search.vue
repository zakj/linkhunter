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

    <hr :class="{[$style.rule]: true, [$style.raised]: isScrolled}">

    <ul :class="$style.list" v-if="filteredBookmarks.length > 0">
      <virtual-list :start="scrollIndex" :size="58" :remain="9"
        :onscroll="handleListScroll" ref="virtualList">
        <li v-for="(bookmark, i) in filteredBookmarks" :key="i">
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
      </virtual-list>
    </ul>
  </div>
</template>

<style lang="stylus" module>
  @require '../util'

  .top
    display flex

  .rule
    border none
    margin 8px -7px -3px
    position relative

    &::before, &::after
      content ""
      display block
      height 1px
      opacity 0
      transition opacity 150ms ease-in-out
    &::before
      background:
        linear-gradient(
          to right,
          rgba(#fff, 1),
          rgba(#fff, 0) 7%, rgba(#fff, 0) 93%,
          rgba(#fff, 1)),
        rgba(lh-grey-4, .5)
    &::after
      background:
        linear-gradient(
          to right,
          rgba(#fff, 1),
          rgba(#fff, 0) 7%, rgba(#fff, 0) 93%,
          rgba(#fff, 1)),
        lh-grey-d
    &.raised
      &::before
        opacity 1
      &::after
        opacity .5

  .filter
    @extend $input
    flex 1

  .button
    @extend $button
    @extend $hide-text
    margin-left 8px
    width 40px

  .button-add
    @extend .button

  .button-settings
    @extend .button
    background lh-grey-4

  .list
    list-style none
    margin-bottom 0
    margin-top 2px
    padding 0
    > div
      // HACK: keep some space at the top of the virtual container.
      box-sizing content-box
      padding-top 6px
    li
      padding-top 2px

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
  import VirtualList from 'vue-virtual-scroll-list';

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
        isScrolled: false,
        scrollIndex: 0,
        selectedIndex: 0,
      };
    },

    directives: {focus},
    components: {VirtualList},

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
            this.scrollIndex = Math.max(0, this.selectedIndex - 4);
          },
          ArrowUp: () => {
            this.selectedIndex = Math.max(0, this.selectedIndex - 1);
            this.scrollIndex = Math.max(0, this.selectedIndex - 4);
          },
        }[ev.key];
        if (handler) handler();
      },

      handleListScroll(ev, position) {
        this.isScrolled = position > 0;
      },

      handleSearchInput(ev) {
        if (this.filterString !== ev.target.value) {
          this.$refs.virtualList.$refs.container.scrollTop = 0;  // HACK
          this.scrollIndex = 0;
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
