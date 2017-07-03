<template>
  <div>
    <pane :class="$style.settings" :showClose="token" title="Linkhunter">
      <div :class="$style.auth" v-if="token">
        <div :class="$style.username">{{ username }}</div>
        <div>Mark new links private by default</div>
        <toggle :on="defaultPrivate" @toggle="toggleDefaultPrivate"></toggle>

        <a @click="openKeyboardShortcuts" v-if="shortcut">
          <span v-if="shortcut === NO_SHORTCUT">Assign a keyboard shortcut</span>
          <span v-else>Open with <span v-html="friendlyShortcut"></span></span>
        </a>
      </div>

      <div :class="$style.auth" v-else>
        <div v-if="loggedIn">
          <p>&nbsp;</p>
          <a :class="$style.button" @click="updateToken">Connect to Pinboard</a>
        </div>
        <div v-else>
          <p>Oi! You're not logged in.</p>
          <a :class="$style.button" @click="login">Log in on Pinboard</a>
        </div>
      </div>
    </pane>

    <footer :class="$style.footer">
      <a v-if="token" @click="clearToken" :class="$style.logout">
        Logout
      </a>
      <div :class="$style.attribution">
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

  .auth
    margin-top 42px
    text-align center

  .button
    @extend $button

  .username
    font-size 24px
    font-weight bold
    line-height 28px
    margin-bottom 5px

  .footer
    @extend $light-text
    display flex
    margin-top 2px

  .logout
    @extend $pane
    margin-right 2px
    &:hover  // XXX needs design
      background-image linear-gradient(170deg, rgba(#fff, 50%), rgba(#fff, 0) 80%)

  .attribution
    @extend $pane
    flex 1
    text-align right

  .dot
    margin 0 8px
</style>

<script>
  import {checkLoggedIn} from '@/pinboard';
  import {openUrl, sendMessage} from '@/browser';
  import {mapGetters, mapState} from 'vuex';
  import Pane from '@/components/pane';
  import Toggle from '@/components/toggle';

  const SHORTCUT_KEYS = {
    Alt:     '&#x2325;',  // ⌥
    Command: '&#x2318;',  // ⌘
    Ctrl:    '&#x2303;',  // ⌃
    Option:  '&#x2325;',  // ⌥
    Shift:   '&#x21E7;',  // ⇧
  };

  export default {
    components: {Pane, Toggle},

    data() {
      return {
        loggedIn: null,
        NO_SHORTCUT: Symbol(),
        shortcut: null,
        tweeningIconPath: null,
      };
    },

    computed: {
      ...mapGetters(['username']),
      ...mapState(['defaultPrivate', 'token']),
      friendlyShortcut() {
        return this.shortcut && this.shortcut.split('+')
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

      toggleDefaultPrivate() {
        this.$store.commit('toggleDefaultPrivate');
      },

      updateToken() {
        sendMessage({type: 'updateToken'});
      },
    },

    mounted() {
      chrome.commands.getAll(commands => {
        const action = commands.find(c => c.name === '_execute_browser_action');
        this.shortcut = action && action.shortcut || this.NO_SHORTCUT;
      });
      // TODO: this doesn't work via a sendMessage. why?
      checkLoggedIn().then(val => this.loggedIn = val);
    },
  };
</script>
