<template>
  <OrbitSpinner v-if="!idle" :size="16" />
  <va-button v-if="!editing && idle" plain @click="beginEdit">
    <va-icon :name="'material-icons-edit'" />
  </va-button>

  <va-counter v-if="editing" v-model="pendingValue" buttons manual-input style="width: 300px">
    <template #decreaseAction>
      <va-button-group plain>
        <va-button @click="cancelEdit"><va-icon :name="'material-icons-cancel'" /></va-button>
        <va-button v-for="step in steps" :key="step" class="!px-0" @click="updateValue(-step)"> -{{ step }} </va-button>
      </va-button-group>
    </template>
    <template #increaseAction>
      <va-button-group plain>
        <va-button v-for="step in steps" :key="step" class="!px-0" @click="updateValue(step)"> +{{ step }} </va-button>
        <va-button @click="applyEdit"><va-icon :name="'material-icons-done'" /></va-button>
      </va-button-group>
    </template>
  </va-counter>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { OrbitSpinner } from 'epic-spinners'
  import { useToast } from 'vuestic-ui'
  import { defineComponent } from 'vue'

  export default defineComponent({
    components: {
      OrbitSpinner,
    },
    props: {
      deviceId: { type: String, required: true },
      nodeId: { type: String, required: true },
      propId: { type: String, required: true },
      value: { type: Number, required: true },
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
        steps: [0.01, 10],
        pendingValue: 0.0,
      }
    },
    methods: {
      beginEdit() {
        if (this.value == null) {
          return
        }
        this.pendingValue = this.value
        this.editing = true
      },
      updateValue(step: number) {
        this.pendingValue += step
        this.pendingValue = parseFloat(this.pendingValue.toFixed(3))
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
