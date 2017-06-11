<template>
  <div>
    <div :class="$style.settings" class="pane">
      <router-link to="/" class="close-button">Close</router-link>
      <div style="width: 56px; height: 56px; outline: 1px solid orange;">MARK</div>
      <div style="outline: 1px solid orange;">Linkhunter</div>

      <div v-if="token">
        <div :class="$style.username">{{ username }}</div>
        <label for="defaultPrivate">Mark new links private by default</label>
        <input id="defaultPrivate" type="checkbox" :value="defaultPrivate">

        <div v-if="shortcut" @click="openKeyboardShortcuts">
          <span v-if="shortcut === NO_SHORTCUT">Assign a keyboard shortcut.</span>
          <span v-else>Open with <span v-html="friendlyShortcut"></span></span>
        </div>
      </div>

      <div v-else>
        <div v-if="loggedIn">
          <button @click="updateToken">Connect to Pinboard</button>
        </div>
        <div v-else>
          Oi! You're not logged in.
          <button @click="login">Log in on Pinboard</button>
        </div>
      </div>
    </div>

    <footer :class="$style.footer">
      <a v-if="token" @click="clearToken" :class="$style.logout" class="pane">
        Logout
      </a>
      <div :class="$style.attribution" class="pane">
        <a @click="openFeedbackPage">Feedback</a>
        <span :class="$style.dot">·</span>
        Made by <a @click="openHomepage">Zak Johnson</a>
      </div>
    </footer>
  </div>
</template>

<style lang="stylus" module>
  @require '../util'

  .settings
    align-items center
    display flex
    flex-direction column
    padding 48px

  .username
    font-size 24px
    font-weight bold
    line-height 28px

  .footer
    @extend $light-text
    display flex
    margin-top 2px

  .logout
    margin-right 2px
    &:hover  // XXX needs design
      background-image linear-gradient(150deg, rgba(#fff, 50%), rgba(#fff, 0) 80%)

  .attribution
    flex 1
    text-align right

  .dot
    margin 0 8px
</style>

<script>
  import {checkLoggedIn} from '@/pinboard';
  import {openUrl, sendMessage} from '@/browser';
  import {mapGetters, mapState} from 'vuex';

  const SHORTCUT_KEYS = {
    Alt:     '&#x2325;',  // ⌥
    Command: '&#x2318;',  // ⌘
    Ctrl:    '&#x2303;',  // ⌃
    Option:  '&#x2325;',  // ⌥
    Shift:   '&#x21E7;',  // ⇧
  };

  export default {
    data() {
      return {
        loggedIn: null,
        NO_SHORTCUT: Symbol(),
        shortcut: null,
      };
    },

    computed: {
      ...mapGetters(['username']),
      ...mapState(['defaultPrivate', 'token']),
      friendlyShortcut() {
        return this.shortcut.split('+')
          .map(v => SHORTCUT_KEYS[v] || `${v} `).join('').trim();
      },
    },

    methods: {
      login() {
        openUrl({url: 'https://pinboard.in/'});
      },

      clearToken() {
        this.$store.commit('changeToken', null);
      },

      openFeedbackPage() {
        openUrl({url: 'https://chrome.google.com/webstore/detail/linkhunter/ndjggnnohdkheiijjhbklkanjcpibbng/support'});
      },

      openHomepage() {
        openUrl({url: 'https://zakj.net/'});
      },

      openKeyboardShortcuts() {
        openUrl({url: 'chrome://extensions/configureCommands'});
      },

      updateToken() {
        sendMessage({type: 'updateToken'});
      },
    },

    mounted() {
      const vm = this;
      chrome.commands.getAll(commands => {
        const action = commands.find(c => c.name === '_execute_browser_action');
        vm.shortcut = action && action.shortcut || vm.NO_SHORTCUT;
      });
      // TODO: this doesn't work via a sendMessage. why?
      checkLoggedIn().then(val => vm.loggedIn = val);
    },
  };
</script>
