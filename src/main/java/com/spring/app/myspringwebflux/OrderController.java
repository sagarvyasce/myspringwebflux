package com.spring.app.myspringwebflux;

import org.springframework.web.bind.annotation.GetMapping;
	import org.springframework.web.bind.annotation.DeleteMapping;
	import org.springframework.web.bind.annotation.PostMapping;
	import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/orders")
public class OrderController {

	private final OrderService orderService;

	public OrderController(OrderService orderService) {
		this.orderService = orderService;
	}

	@GetMapping
	public Flux<Order> fetchAllOrders() {
		return orderService.fetchAllOrders();
	}

	@GetMapping("/{orderId}")
	public Mono<Order> fetchOrderByOrderId(@PathVariable int orderId) {
		return orderService.fetchOrderByOrderId(orderId);
	}

	@PostMapping
	public Mono<Order> addOrder(@RequestBody Order order) {
		return orderService.addOrder(order);
	}

	@DeleteMapping("/{orderId}")
	public Mono<Boolean> deleteOrderById(@PathVariable int orderId) {
		return orderService.deleteOrderById(orderId);
	}
}