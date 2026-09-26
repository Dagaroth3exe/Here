import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { ChatService } from './chat.service.js';
import { HistoryQueryDto } from './dto/history-query.dto.js';
import { SendMessageDto } from './dto/send-message.dto.js';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('conversations')
  conversations(@Req() request: AuthedRequest) {
    return this.chatService.conversations(request.userId);
  }

  /** Unread messages and waiting chat requests, for the Chats tab badge. */
  @Get('unread')
  unread(@Req() request: AuthedRequest) {
    return this.chatService.unread(request.userId);
  }

  /** Works whether or not the sender has a live socket (i.e. is Reachable). */
  @Post('messages')
  send(@Req() request: AuthedRequest, @Body() dto: SendMessageDto) {
    return this.chatService.send(request.userId, dto.targetId, dto.body);
  }

  /** A page of messages, newest page first: pass `before` (an ISO time) to scroll back. */
  @Get('messages/:otherUserId')
  messages(
    @Req() request: AuthedRequest,
    @Param('otherUserId', ParseUUIDPipe) otherUserId: string,
    @Query() query: HistoryQueryDto,
  ) {
    return this.chatService.history(request.userId, otherUserId, query.before ? new Date(query.before) : undefined);
  }

  @Post('read/:otherUserId')
  @HttpCode(HttpStatus.NO_CONTENT)
  read(@Req() request: AuthedRequest, @Param('otherUserId', ParseUUIDPipe) otherUserId: string) {
    return this.chatService.markRead(request.userId, otherUserId);
  }

  @Post('requests/:userId/accept')
  @HttpCode(HttpStatus.NO_CONTENT)
  accept(@Req() request: AuthedRequest, @Param('userId', ParseUUIDPipe) userId: string) {
    return this.chatService.respond(request.userId, userId, true);
  }

  @Post('requests/:userId/decline')
  @HttpCode(HttpStatus.NO_CONTENT)
  decline(@Req() request: AuthedRequest, @Param('userId', ParseUUIDPipe) userId: string) {
    return this.chatService.respond(request.userId, userId, false);
  }
}
