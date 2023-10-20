<template>
<div>
    {{ this.device_id }}
</div>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { useRoute } from 'vue-router';

  export default {

    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {
        device_id: "",
        timerId: 0,
      }
    },

    mounted() {
        this.device_id = useRoute().params.id
        if (this.timerId == 0){
            this.timerId = window.setInterval(() => { this.getData() }, 5*1000)
      }
    },
    unmounted() {
        if (this.timerId != 0){
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },

    beforeRouteUpdate(to, from) {
        this.device_id = to.params.id
    },

    methods: {
        getData() {
            // deviceService.summary().then(data => this.deviceData = data)
        }
    }
  }
</script>