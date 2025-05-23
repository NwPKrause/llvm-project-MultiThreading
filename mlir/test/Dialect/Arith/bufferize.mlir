// RUN: mlir-opt %s --one-shot-bufferize="dialect-filter=arith,bufferization copy-before-write unknown-type-conversion=identity-layout-map" -split-input-file -verify-diagnostics | FileCheck %s

// CHECK-LABEL:   func @index_cast(
// CHECK-SAME:  %[[TENSOR:.*]]: tensor<i32>, %[[SCALAR:.*]]: i32
func.func @index_cast(%tensor: tensor<i32>, %scalar: i32) -> (tensor<index>, index) {
  %index_tensor = arith.index_cast %tensor : tensor<i32> to tensor<index>
  %index_scalar = arith.index_cast %scalar : i32 to index
  return %index_tensor, %index_scalar : tensor<index>, index
}
// CHECK:  %[[MEMREF:.*]] = bufferization.to_buffer %[[TENSOR]] : tensor<i32>
// CHECK-NEXT: %[[INDEX_MEMREF:.*]] = arith.index_cast %[[MEMREF]]
// CHECK-SAME:   memref<i32> to memref<index>
// CHECK-NEXT: %[[INDEX_TENSOR:.*]] = bufferization.to_tensor %[[INDEX_MEMREF]]
// CHECK: return %[[INDEX_TENSOR]]

// -----

// CHECK-LABEL: module {

// We check the debug name too since we put some effort into making that readable.
// The name isn't load-bearing though.

// CHECK: memref.global "private" constant @__constant_3x4xf32 : memref<3x4xf32> = dense<7.000000e+00>
// CHECK-SAME: {alignment = 64 : i64}

// CHECK: @basic
func.func @basic() -> tensor<3x4xf32> {
  // CHECK: %[[MEMREF:.*]] = memref.get_global @__constant_3x4xf32 : memref<3x4xf32>
  // CHECK: %[[TENSOR:.*]] = bufferization.to_tensor %[[MEMREF]]
  %0 = arith.constant dense<7.0> : tensor<3x4xf32>
  // CHECK: return %[[TENSOR]]
  return %0 : tensor<3x4xf32>
}

// CHECK: }

// -----

// CHECK-LABEL: module {

// Only one global is created.
// CHECK: memref.global
// CHECK-NOT: memref.global
func.func @duplicate_constants() -> (tensor<3x4xf32>, tensor<3x4xf32>) {
  %0 = arith.constant dense<7.0> : tensor<3x4xf32>
  %1 = arith.constant dense<7.0> : tensor<3x4xf32>
  return %0, %1 : tensor<3x4xf32>, tensor<3x4xf32>
}

// CHECK: }

// -----

// CHECK-LABEL: module {

// Two globals are created.
// CHECK: memref.global
// CHECK: memref.global
// CHECK-NOT: memref.global
func.func @multiple_constants() -> (tensor<3x4xf32>, tensor<3x4xf32>) {
  %0 = arith.constant dense<7.0> : tensor<3x4xf32>
  %1 = arith.constant dense<8.0> : tensor<3x4xf32>
  return %0, %1 : tensor<3x4xf32>, tensor<3x4xf32>
}

// CHECK: }

// -----

// CHECK-LABEL: module {
// We don't convert non-tensor globals.
// CHECK-NOT: memref.global
func.func @non_tensor() {
    %0 = arith.constant 7 : i32
    return
}

// CHECK: }

// -----

// CHECK-LABEL:   func @select(
// CHECK-SAME:                 %[[PRED:.*]]: i1,
// CHECK-SAME:                 %[[TRUE_VAL:.*]]: tensor<f32>,
// CHECK-SAME:                 %[[FALSE_VAL:.*]]: tensor<f32>) -> tensor<f32> {
// CHECK-DAG:           %[[TRUE_VAL_MEMREF:.*]] = bufferization.to_buffer %[[TRUE_VAL]] : tensor<f32>
// CHECK-DAG:           %[[FALSE_VAL_MEMREF:.*]] = bufferization.to_buffer %[[FALSE_VAL]] : tensor<f32>
// CHECK:           %[[RET_MEMREF:.*]] = arith.select %[[PRED]], %[[TRUE_VAL_MEMREF]], %[[FALSE_VAL_MEMREF]] : memref<f32>
// CHECK:           %[[RET:.*]] = bufferization.to_tensor %[[RET_MEMREF]] : memref<f32>
// CHECK:           return %[[RET]] : tensor<f32>
func.func @select(%arg0: i1, %arg1: tensor<f32>, %arg2: tensor<f32>) -> tensor<f32> {
  %0 = arith.select %arg0, %arg1, %arg2 : tensor<f32>
  return %0 : tensor<f32>
}

// -----

func.func @elementwise_select(%arg0: tensor<5xi1>, %arg1: tensor<5xi32>, %arg2: tensor<5xi32>) -> tensor<5xi32> {
  // expected-error @below{{only i1 condition values are supported}}
  // expected-error @below{{failed to bufferize op}}
  %0 = arith.select %arg0, %arg1, %arg2 : tensor<5xi1>, tensor<5xi32>
  return %0 : tensor<5xi32>
}
