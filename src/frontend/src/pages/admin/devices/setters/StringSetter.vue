<template>
  <busy-spinner v-if="!idle" :size="16" />
  <va-button v-if="!editing && idle" plain @click="beginEdit">
    <va-icon :name="'material-icons-edit'" />
  </va-button>

  <va-input v-if="editing" v-model="pendingValue" class="mb-6" style="width: 200px">
    <template #prepend>
      <va-button plain @click="applyEdit"><va-icon :name="'material-icons-done'" /></va-button>
    </template>
    <template #append>
      <va-button plain @click="cancelEdit"><va-icon :name="'material-icons-cancel'" /></va-button>
    </template>
  </va-input>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { useToast } from 'vuestic-ui'
  import { defineComponent } from 'vue'

  export default defineComponent({
    // components: { },
    props: {
      deviceId: { type: String, required: true },
      nodeId: { type: String, required: true },
      propId: { type: String, required: true },
      value: { type: String, required: true },
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
        editing: false,
        pendingValue: '',
      }
    },
    methods: {
      beginEdit() {
        this.pendingValue = ''
        if (this.value != null) {
          this.pendingValue = this.value
        }
        this.editing = true
      },
      cancelEdit() {
        this.editing = false
      },
      applyEdit() {
        if (this.deviceId && this.nodeId && this.propId) {
          this.idle = false
          deviceService
            .setProperty(this.deviceId, this.nodeId, this.propId, this.pendingValue)
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
        this.editing = false
      },
    },
  })
</script>

<style></style>
