<template>
  <va-card class="mb-2">
    <va-card-title>{{ t('deviceInfo.details.actions.title') }}</va-card-title>
    <va-card-content>
      <va-button
        preset="primary"
        class="mr-6 mb-2"
        round
        icon="loop"
        border-color="primary"
        hover-behavior="opacity"
        :hover-opacity="0.4"
        @click="confirmCommand('restart')"
      >
        {{ t('deviceInfo.details.actions.restart') }}
      </va-button>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { useModal, useToast } from 'vuestic-ui'

  export default defineComponent({
    props: {
      deviceId: {
        type: String,
        required: true,
      },
    },
    setup(Properties, { emit }) {
      const { t } = useI18n()
      const { init } = useToast()
      const { confirm } = useModal()
      return { t, emit, showModalConfirm: confirm, toastShow: init }
    },
    data() {
      return {
        idle: true,
      }
    },
    methods: {
      async executeCommand(command: string) {
        if (!this.idle) {
          this.toastShow({
            message: this.t('deviceInfo.details.actions.busy'),
            color: 'warning',
          })
          return
        }
        this.idle = false
        deviceService
          .sendCommand(this.deviceId, command)
          .then(() => {
            this.toastShow({
              message: this.t('deviceInfo.details.actions.command_send'),
              color: 'success',
            })
          })
          .catch(() => {
            this.toastShow({
              message: this.t('deviceInfo.details.actions.command_failed'),
              color: 'danger',
            })
          })
          .finally(() => {
            this.idle = true
          })
      },

      async confirmCommand(command: string) {
        this.showModalConfirm({
          message: this.t('deviceInfo.details.actions.confirm'),
          blur: true,
          onOk: () => {
            this.executeCommand(command)
          },
          // onCancel: () => {},
        })
      },
    },
  })
</script>

<style lang="scss"></style>
