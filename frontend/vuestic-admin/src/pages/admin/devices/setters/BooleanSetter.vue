<template>
  <busy-spinner v-if="!idle" :size="16" />
  <va-button v-if="idle && deviceId && nodeId && propId" preset="plain" size="small" @click="onToggle">
    {{ t('deviceInfo.setter.toggle') }}
  </va-button>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { useToast } from 'vuestic-ui'
  import { defineComponent } from 'vue'

  export default defineComponent({
    components: {},
    props: {
      deviceId: { type: String, required: true },
      nodeId: { type: String, required: true },
      propId: { type: String, required: true },
      value: Boolean,
    },
    emits: ['changed'],
    setup(Properties, { emit }) {
      const { init } = useToast()
      const { t } = useI18n()
      return { t, emit, toastShow: init }
    },
    data() {
      return {
        idle: true,
      }
    },
    methods: {
      onToggle() {
        this.idle = false
        if (this.deviceId && this.nodeId && this.propId) {
          deviceService
            .setProperty(this.deviceId, this.nodeId, this.propId, !this.value)
            .then(() =>
              this.toastShow({
                message: this.t('deviceInfo.nodes.setSuccess'),
                color: 'success',
              }),
            )
            .catch(() =>
              this.toastShow({
                message: this.t('deviceInfo.nodes.setFailure'),
                color: 'warning',
              }),
            )
            .finally(() => {
              this.idle = true
              this.emit('changed')
            })
        }
      },
    },
  })
</script>

<style></style>
