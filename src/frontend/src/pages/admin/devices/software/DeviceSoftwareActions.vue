<template>
  <va-card class="mb-2">
    <va-card-title>{{ t('deviceInfo.software.actions.title') }}</va-card-title>
    <va-card-content>
      <div class="flex">
        <va-button
          preset="primary"
          class="mr-6 mb-2"
          round
          icon="loop"
          border-color="primary"
          hover-behavior="opacity"
          :hover-opacity="0.4"
          @click="triggerOta()"
        >
          {{ t('deviceInfo.software.actions.triggerOTA') }}
        </va-button>

        <va-button
          preset="primary"
          class="mr-6 mb-2"
          round
          icon="loop"
          border-color="primary"
          hover-behavior="opacity"
          :hover-opacity="0.4"
          @click="restartDevice()"
        >
          {{ t('deviceInfo.software.actions.restart') }}
        </va-button>

        <va-spacer />

        <!-- <va-button
          preset="primary"
          class="mr-6 mb-2"
          round
          icon="delete_forever"
          border-color="primary"
          hover-behavior="opacity"
          :hover-opacity="0.4"
          @click="deleteDevice"
        >
          {{ t('deviceInfo.software.actions.delete_device') }}
        </va-button> -->
      </div>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import firmwareService from '../../../../services/fairyNode/FirmwareService'
  import { GenericResult } from '../../../../services/fairyNode/http-common'
  import { useModal, useToast } from 'vuestic-ui'

  export declare type PromiseFunc = () => Promise<GenericResult>

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
      async executeCommand(func: PromiseFunc) {
        if (!this.idle) {
          this.toastShow({
            message: this.t('deviceInfo.software.actions.busy'),
            color: 'warning',
          })
          return
        }
        this.idle = false
        func()
          .then(() => {
            this.toastShow({
              message: this.t('deviceInfo.software.actions.command_send'),
              color: 'success',
            })
          })
          .catch(() => {
            this.toastShow({
              message: this.t('deviceInfo.software.actions.command_failed'),
              color: 'danger',
            })
          })
          .finally(() => {
            this.idle = true
          })
      },

      async confirmCommand(func: PromiseFunc) {
        this.showModalConfirm({
          message: this.t('deviceInfo.software.actions.confirm'),
          blur: true,
          onOk: () => {
            this.executeCommand(func)
          },
        })
      },

      restartDevice() {
        this.confirmCommand(() => deviceService.restartDevice(this.deviceId))
      },
      triggerOta() {
        this.confirmCommand(() => firmwareService.triggerOta(this.deviceId))
      },
    },
  })
</script>

<style lang="scss"></style>
