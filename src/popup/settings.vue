<template>
  <div>
    <div class="pane">
      LOGO<br>
      Linkhunter<br>
      close button<br>

      <div v-if="token">
        {{ username }}<br>
        <label>
          Mark new links private by default
          <input type="checkbox" :value="defaultPrivate">
        </label>
      </div>
      <div v-else>
        Oi! You're not logged in.
        <button @click="login">Log in on Pinboard</button>
      </div>
    </div>
    <a class="pane" @click="logout">
      Logout
    </a>
    <div class="pane">
    </div>
  </div>
</template>

<style lang="stylus">
</style>

<script>
  import {sendMessage} from '@/browser';
  import {mapGetters, mapState} from 'vuex';

  export default {
    computed: {
      ...mapGetters(['username']),
      ...mapState(['defaultPrivate', 'token']),
    },

    methods: {
      login() {
        this.$store.commit('changeToken', 'zakj:XXX');
        // XXX how to make sure commit to storage happens before updatebookmarks?
        sendMessage({type: 'updateBookmarks'});
        this.$router.push('/');
      },
      logout() {
        this.$store.commit('changeToken', null);
      },
    },
  };
</script>
