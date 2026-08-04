import assert from "node:assert/strict"
import test from "node:test"

import AccountDeletionController from "../../app/javascript/controllers/account_deletion_controller.js"

const buildController = ({ checked, passwordRequired, password = "" }) => {
  const controller = Object.create(AccountDeletionController.prototype)
  const submit = { disabled: false }
  const properties = {
    confirmationTargets: {
      value: checked.map((value) => ({ checked: value }))
    },
    submitTarget: { value: submit },
    passwordRequiredValue: { value: passwordRequired },
    hasPasswordTarget: { value: passwordRequired }
  }

  if (passwordRequired) {
    properties.passwordTarget = { value: { value: password } }
  }

  Object.defineProperties(controller, properties)

  return { controller, submit }
}

test("初期状態では削除ボタンを無効にする", () => {
  const { controller, submit } = buildController({
    checked: [false, false, false, false],
    passwordRequired: false
  })

  controller.connect()

  assert.equal(submit.disabled, true)
})

test("4項目すべてのチェックで削除ボタンを有効にする", () => {
  const { controller, submit } = buildController({
    checked: [true, true, true, true],
    passwordRequired: true,
    password: "password"
  })

  controller.updateSubmitState()

  assert.equal(submit.disabled, false)
})

test("1項目のチェックを外すと削除ボタンを再び無効にする", () => {
  const { controller, submit } = buildController({
    checked: [true, true, false, true],
    passwordRequired: true,
    password: "password"
  })

  controller.updateSubmitState()

  assert.equal(submit.disabled, true)
})

test("通常ユーザーはパスワードが空なら全項目チェック済みでも無効にする", () => {
  const { controller, submit } = buildController({
    checked: [true, true, true, true],
    passwordRequired: true
  })

  controller.updateSubmitState()

  assert.equal(submit.disabled, true)
})

test("Google専用ユーザーはパスワード欄なしで全項目チェック時に有効にする", () => {
  const { controller, submit } = buildController({
    checked: [true, true, true, true],
    passwordRequired: false
  })

  controller.updateSubmitState()

  assert.equal(submit.disabled, false)
})
