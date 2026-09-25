import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { ChatService } from './chat.service.js';
import { SendMessageDto } from './dto/send-message.dto.js';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('conversations')
  conversations(@Req() request: AuthedRequest) {
    return this.chatService.conversations(request.userId);
  }

  /** Works whether or not the sender has a live socket (i.e. is Reachable). */
  @Post('messages')
  send(@Req() request: AuthedRequest, @Body() dto: SendMessageDto) {
    return this.chatService.send(request.userId, dto.targetId, dto.body);
  }

  @Get('messages/:otherUserId')
  messages(@Req() request: AuthedRequest, @Param('otherUserId') otherUserId: string) {
    return this.chatService.history(request.userId, otherUserId);
  }
}
