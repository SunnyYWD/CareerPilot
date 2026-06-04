package com.SmartHire.common.logging;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.websocket.Session;
import java.lang.reflect.Array;
import java.lang.reflect.Method;
import java.security.Principal;
import java.time.Duration;
import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.StringJoiner;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Aspect
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 100)
public class DataLinkLoggingAspect {

  private static final int MAX_TEXT_LENGTH = 1200;
  private static final int MAX_COLLECTION_ITEMS = 8;
  private static final Set<String> SENSITIVE_KEYS =
      Set.of("password", "passwd", "token", "authorization", "code", "secret", "credential");

  private final ObjectMapper objectMapper;

  public DataLinkLoggingAspect(ObjectMapper objectMapper) {
    this.objectMapper = objectMapper.copy().findAndRegisterModules();
  }

  @Pointcut(
      "execution(* com.SmartHire..controller..*(..))"
          + " || execution(* com.SmartHire..service..*(..))"
          + " || execution(* com.SmartHire..mapper..*(..))")
  public void dataLinkBoundary() {}

  @Around("dataLinkBoundary()")
  public Object logDataLink(ProceedingJoinPoint joinPoint) throws Throwable {
    DataLinkTraceContext.TraceScope scope = DataLinkTraceContext.enter();
    long startNanos = System.nanoTime();
    MethodSignature signature = (MethodSignature) joinPoint.getSignature();
    Method method = signature.getMethod();
    String layer = detectLayer(joinPoint.getTarget(), signature);
    String methodName = signature.getDeclaringTypeName() + "." + signature.getName();
    String indent = indent(scope.depth());

    stdout(
        "%s[DATA-LINK][START] traceId=%s layer=%s method=%s thread=%s user=%s args=%s",
        indent,
        scope.traceId(),
        layer,
        methodName,
        Thread.currentThread().getName(),
        currentUserSummary(),
        argumentsSummary(method, signature.getParameterNames(), joinPoint.getArgs()));

    try {
      Object result = joinPoint.proceed();
      long costMs = Duration.ofNanos(System.nanoTime() - startNanos).toMillis();
      stdout(
          "%s[DATA-LINK][END] traceId=%s layer=%s method=%s costMs=%d result=%s",
          indent, scope.traceId(), layer, methodName, costMs, valueSummary(null, result));
      return result;
    } catch (Throwable ex) {
      long costMs = Duration.ofNanos(System.nanoTime() - startNanos).toMillis();
      stdout(
          "%s[DATA-LINK][ERROR] traceId=%s layer=%s method=%s costMs=%d exception=%s message=%s",
          indent,
          scope.traceId(),
          layer,
          methodName,
          costMs,
          ex.getClass().getName(),
          limit(ex.getMessage()));
      throw ex;
    } finally {
      DataLinkTraceContext.exit(scope);
    }
  }

  private String detectLayer(Object target, MethodSignature signature) {
    String name =
        target == null ? signature.getDeclaringTypeName() : target.getClass().getName();
    if (name.contains(".controller.")) {
      return "CONTROLLER";
    }
    if (name.contains(".mapper.")) {
      return "MAPPER";
    }
    if (name.contains(".websocket.")) {
      return "WEBSOCKET";
    }
    if (name.contains(".service.")) {
      if (name.endsWith("Producer") || name.contains("EventProducer")) {
        return "MQ_PRODUCER";
      }
      if (name.endsWith("Consumer") || name.contains("EventConsumer")) {
        return "MQ_CONSUMER";
      }
      if (name.endsWith("ApiImpl")) {
        return "INTERNAL_API";
      }
      return "SERVICE";
    }
    return "DATA";
  }

  private String argumentsSummary(Method method, String[] parameterNames, Object[] args) {
    if (args == null || args.length == 0) {
      return "[]";
    }
    StringJoiner joiner = new StringJoiner(", ", "[", "]");
    for (int i = 0; i < args.length; i++) {
      String name = parameterName(method, parameterNames, i);
      joiner.add(name + "=" + valueSummary(name, args[i]));
    }
    return joiner.toString();
  }

  private String parameterName(Method method, String[] parameterNames, int index) {
    if (parameterNames != null && index < parameterNames.length && parameterNames[index] != null) {
      return parameterNames[index];
    }
    if (method.getParameters().length > index && method.getParameters()[index].isNamePresent()) {
      return method.getParameters()[index].getName();
    }
    return "arg" + index;
  }

  private String valueSummary(String name, Object value) {
    if (value == null) {
      return "null";
    }
    if (isSensitiveKey(name)) {
      return "\"***\"";
    }
    if (value instanceof CharSequence text) {
      return "\"" + limit(maskSensitiveText(text.toString())) + "\"";
    }
    if (value instanceof Number || value instanceof Boolean || value instanceof Enum<?>) {
      return String.valueOf(value);
    }
    if (value instanceof MultipartFile file) {
      return "MultipartFile{name=\""
          + file.getName()
          + "\", originalFilename=\""
          + limit(file.getOriginalFilename())
          + "\", contentType=\""
          + file.getContentType()
          + "\", size="
          + file.getSize()
          + "}";
    }
    if (value instanceof HttpServletRequest request) {
      return "HttpServletRequest{method=\""
          + request.getMethod()
          + "\", uri=\""
          + request.getRequestURI()
          + "\", query=\""
          + limit(request.getQueryString())
          + "\", remoteAddr=\""
          + request.getRemoteAddr()
          + "\"}";
    }
    if (value instanceof ServletRequest request) {
      return "ServletRequest{remoteAddr=\"" + request.getRemoteAddr() + "\"}";
    }
    if (value instanceof ServletResponse response) {
      return "ServletResponse{class=\"" + response.getClass().getSimpleName() + "\"}";
    }
    if (value instanceof Session session) {
      return "WebSocketSession{id=\"" + session.getId() + "\", open=" + session.isOpen() + "}";
    }
    if (value instanceof Page<?> page) {
      return "Page{current="
          + page.getCurrent()
          + ", size="
          + page.getSize()
          + ", total="
          + page.getTotal()
          + ", records="
          + collectionSummary(page.getRecords())
          + "}";
    }
    if (value instanceof Collection<?> collection) {
      return collectionSummary(collection);
    }
    if (value instanceof Map<?, ?> map) {
      return mapSummary(map);
    }
    if (value.getClass().isArray()) {
      return arraySummary(value);
    }
    return objectSummary(value);
  }

  private String collectionSummary(Collection<?> collection) {
    StringJoiner joiner = new StringJoiner(", ", "Collection{size=" + collection.size() + ", items=[", "]}");
    Iterator<?> iterator = collection.iterator();
    int count = 0;
    while (iterator.hasNext() && count < MAX_COLLECTION_ITEMS) {
      joiner.add(valueSummary(null, iterator.next()));
      count++;
    }
    if (collection.size() > MAX_COLLECTION_ITEMS) {
      joiner.add("...");
    }
    return limit(joiner.toString());
  }

  private String mapSummary(Map<?, ?> map) {
    StringJoiner joiner = new StringJoiner(", ", "Map{size=" + map.size() + ", entries={", "}}");
    int count = 0;
    for (Map.Entry<?, ?> entry : map.entrySet()) {
      if (count >= MAX_COLLECTION_ITEMS) {
        joiner.add("...");
        break;
      }
      String key = String.valueOf(entry.getKey());
      joiner.add(key + "=" + valueSummary(key, entry.getValue()));
      count++;
    }
    return limit(joiner.toString());
  }

  private String arraySummary(Object array) {
    int length = Array.getLength(array);
    StringJoiner joiner = new StringJoiner(", ", "Array{length=" + length + ", items=[", "]}");
    for (int i = 0; i < Math.min(length, MAX_COLLECTION_ITEMS); i++) {
      joiner.add(valueSummary(null, Array.get(array, i)));
    }
    if (length > MAX_COLLECTION_ITEMS) {
      joiner.add("...");
    }
    return limit(joiner.toString());
  }

  private String objectSummary(Object value) {
    try {
      JsonNode node = objectMapper.valueToTree(value);
      redact(node);
      return limit(objectMapper.writeValueAsString(node));
    } catch (Exception ex) {
      return limit(value.getClass().getSimpleName() + "{" + String.valueOf(value) + "}");
    }
  }

  private void redact(JsonNode node) {
    if (node == null) {
      return;
    }
    if (node instanceof ObjectNode objectNode) {
      Iterator<String> fields = objectNode.fieldNames();
      while (fields.hasNext()) {
        String field = fields.next();
        if (isSensitiveKey(field)) {
          objectNode.put(field, "***");
        } else {
          redact(objectNode.get(field));
        }
      }
      return;
    }
    if (node instanceof ArrayNode arrayNode) {
      for (JsonNode child : arrayNode) {
        redact(child);
      }
    }
  }

  private String currentUserSummary() {
    try {
      Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
      if (authentication == null) {
        return "anonymous";
      }
      Object principal = authentication.getPrincipal();
      if (principal instanceof Map<?, ?> claims) {
        return "User{id="
            + claims.get("id")
            + ", username=\""
            + claims.get("username")
            + "\", userType="
            + claims.get("userType")
            + "}";
      }
      if (principal instanceof Principal principalObj) {
        return "Principal{name=\"" + principalObj.getName() + "\"}";
      }
      return "Principal{type=\"" + principal.getClass().getSimpleName() + "\"}";
    } catch (Exception ex) {
      return "unknown";
    }
  }

  private boolean isSensitiveKey(String key) {
    if (key == null) {
      return false;
    }
    String normalized = key.toLowerCase(Locale.ROOT);
    return SENSITIVE_KEYS.stream().anyMatch(normalized::contains);
  }

  private String maskSensitiveText(String text) {
    if (text == null) {
      return null;
    }
    if (text.regionMatches(true, 0, "Bearer ", 0, 7)) {
      return "Bearer ***";
    }
    return text;
  }

  private String limit(String text) {
    if (text == null) {
      return "null";
    }
    String clean = text.replace("\r", "\\r").replace("\n", "\\n");
    if (clean.length() <= MAX_TEXT_LENGTH) {
      return clean;
    }
    return clean.substring(0, MAX_TEXT_LENGTH) + "...(truncated, length=" + clean.length() + ")";
  }

  private String indent(int depth) {
    if (depth <= 0) {
      return "";
    }
    char[] chars = new char[Math.min(depth, 12) * 2];
    Arrays.fill(chars, ' ');
    return new String(chars);
  }

  private void stdout(String format, Object... args) {
    System.out.printf((format) + "%n", args);
  }
}
