<template>
  <div v-shortkey="['escape']" @shortkey="XXX()">
    <div :class="$style.settings" class="pane">
      <router-link to="/" class="close-button">Close</router-link>
      <div style="width: 56px; height: 56px; outline: 1px solid orange;">MARK</div>
      <div style="outline: 1px solid orange;">Linkhunter</div>

      <div :class="$style.auth" v-if="token">
        <div :class="$style.username">{{ username }}</div>
        <div>Mark new links private by default</div>
        <div :class="{[$style.toggle]: true, [$style.toggleOn]: defaultPrivate}"
          @click="toggleDefaultPrivate">
          <div :class="$style.toggleButton">
            <svg width="16px" height="16px" viewBox="0 0 16 16" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
              <g :class="$style.toggleIcon" fill="none" stroke-width="2">
                <path ref="togglePath" :d="iconPath" />
              </g>
            </svg>
          </div>
        </div>

        <a @click="openKeyboardShortcuts">
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

  .auth
    margin-top 42px
    text-align center

  .button
    background lh-teal
    border-radius 4px
    color #fff
    display block
    font-size 14px
    font-weight bold
    height 40px
    padding 11px 20px
    text-transform uppercase
    -webkit-font-smoothing antialiased
    &:hover  // XXX needs design
      background-image linear-gradient(170deg, rgba(#fff, 40%), rgba(#fff, 0) 80%)

  .username
    font-size 24px
    font-weight bold
    line-height 28px
    margin-bottom 5px

  .toggle
    background lh-grey-4
    border-radius 24px
    cursor pointer
    height 40px
    margin 12px auto 24px
    padding 1px
    transition background 150ms ease-in-out
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
      stroke-linecap round
      stroke-endcap round

  .footer
    @extend $light-text
    display flex
    margin-top 2px

  .logout
    margin-right 2px
    &:hover  // XXX needs design
      background-image linear-gradient(170deg, rgba(#fff, 50%), rgba(#fff, 0) 80%)

  .attribution
    flex 1
    text-align right

  .dot
    margin 0 8px
</style>

<script>
  import anime from 'animejs';
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

  const ICON_PATHS = {
    [true]: 'M2,8.5 L5.5,12 M5.5,12 L13,4',
    [false]: 'M3,3 L13,13 M3,13 L13,3',
  };

  export default {
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
      iconPath() {
        return this.tweeningIconPath || ICON_PATHS[this.defaultPrivate];
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
      const vm = this;
      chrome.commands.getAll(commands => {
        const action = commands.find(c => c.name === '_execute_browser_action');
        vm.shortcut = action && action.shortcut || vm.NO_SHORTCUT;
      });
      // TODO: this doesn't work via a sendMessage. why?
      checkLoggedIn().then(val => vm.loggedIn = val);
    },

    watch: {
      defaultPrivate(newValue, oldValue) {
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
